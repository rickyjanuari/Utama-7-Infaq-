<script lang="ts">
	import { supabase, type TransactionSummary, type Transaction } from '$lib/supabase';
	import { auth, canCreateTransaction, canViewPenyisihan, isAdmin } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	let summary: TransactionSummary | null = null;
	let recentTransactions: Transaction[] = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			const { data: transactions, error: txError } = await supabase
				.from('transactions')
				.select(`
					*,
					profiles:user_id (name)
				`)
				.order('transaction_date', { ascending: false })
				.order('created_at', { ascending: false })
				.limit(5);

			if (txError) throw txError;

			recentTransactions = (transactions || []).map(t => ({
				...t,
				user_name: t.profiles?.name || 'Unknown'
			}));

			const { data: allTx } = await supabase
				.from('transactions')
				.select('type, amount, is_penyisihan');

			if (allTx) {
				const totals = allTx.reduce((acc, tx) => {
					if (!tx.is_penyisihan) {
						if (tx.type === 'infaq_masuk') {
							acc.total_infaq += Number(tx.amount);
						} else {
							acc.total_pengeluaran += Number(tx.amount);
						}
					}
					if (tx.is_penyisihan) {
						if (tx.type === 'infaq_masuk') {
							acc.total_penyisihan += Number(tx.amount);
						} else {
							acc.total_penyisihan -= Number(tx.amount);
						}
					}
					return acc;
				}, { total_infaq: 0, total_pengeluaran: 0, total_penyisihan: 0 });

				summary = {
					...totals,
					saldo: totals.total_infaq - totals.total_pengeluaran
				};
			}
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load data';
		} finally {
			loading = false;
		}
	});

	function formatCurrency(amount: number) {
		return new Intl.NumberFormat('id-ID', {
			style: 'currency',
			currency: 'IDR',
			minimumFractionDigits: 0,
			maximumFractionDigits: 0
		}).format(amount);
	}

	function formatDate(dateStr: string) {
		return new Date(dateStr).toLocaleDateString('id-ID', {
			day: 'numeric',
			month: 'short'
		});
	}

	// Send WhatsApp
	function sendWhatsApp(tx: Transaction) {
		const text = `*Kuitansi Digital - INFAQ UTUH*%0A%0A` +
			`Tanggal : ${formatDate(tx.transaction_date)} (%23${tx.id.substring(0, 4)})%0A` +
			`Tipe : ${tx.type === 'infaq_masuk' ? 'Infaq Masuk' : 'Pengeluaran'}%0A` +
			`Jumlah : Rp ${formatCurrency(Number(tx.amount))}%0A` +
			`Kategori : ${tx.category || 'Umum'}%0A` +
			`Keterangan : ${tx.description || '-'}%0A%0A` +
			`Terima kasih telah berpartisipasi. Semoga berkah.`;
			
		window.open(`https://wa.me/?text=${text}`, '_blank');
	}

	async function handleLogout() {
		await auth.logout();
		goto('/login');
	}
</script>

<!-- Header -->
<div class="home-header">
	<div class="greeting">
		<p class="greeting-text">Selamat datang,</p>
		<h1 class="greeting-name">{$auth.user?.name?.split(' ')[0]} 👋</h1>
	</div>
	<div class="header-actions" style="display: flex; align-items: center; gap: 0.75rem;">
		<div class="avatar">
			{$auth.user?.name?.charAt(0).toUpperCase() || 'U'}
		</div>
		<button class="logout-btn" on:click={handleLogout} title="Keluar">
			<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
			</svg>
		</button>
	</div>
</div>

{#if loading}
	<div class="loader">
		<div class="spinner"></div>
	</div>
{:else if error}
	<div class="card" style="text-align: center; color: var(--danger);">
		<p>{error}</p>
		<button class="btn btn-primary" style="margin-top: 1rem;" on:click={() => location.reload()}>Coba Lagi</button>
	</div>
{:else if summary}
	<!-- Balance Card -->
	<div class="stats-grid">
		<div class="stat-card full-width">
			<p class="stat-label">Total Saldo</p>
			<p class="stat-value">{formatCurrency(summary.saldo)}</p>
		</div>
		
		<div class="stat-card">
			<div class="stat-icon income-icon">
				<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline>
					<polyline points="17 6 23 6 23 12"></polyline>
				</svg>
			</div>
			<p class="stat-value income">{formatCurrency(summary.total_infaq)}</p>
			<p class="stat-label">Pemasukan</p>
		</div>
		
		<div class="stat-card">
			<div class="stat-icon expense-icon">
				<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<polyline points="23 18 13.5 8.5 8.5 13.5 1 6"></polyline>
					<polyline points="17 18 23 18 23 12"></polyline>
				</svg>
			</div>
			<p class="stat-value expense">{formatCurrency(summary.total_pengeluaran)}</p>
			<p class="stat-label">Pengeluaran</p>
		</div>
	</div>

	{#if $canViewPenyisihan && summary.total_penyisihan && summary.total_penyisihan > 0}
		<div class="penyisihan-card">
			<div class="penyisihan-icon">🔒</div>
			<div class="penyisihan-info">
				<p class="penyisihan-label">Dana Penyisihan</p>
				<p class="penyisihan-value">{formatCurrency(summary.total_penyisihan)}</p>
			</div>
		</div>
	{/if}

	<!-- Quick Actions -->
	{#if $canCreateTransaction}
		<div class="quick-actions">
			<a href="/infaq?type=infaq_masuk" class="quick-action-btn income-btn">
				<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="12" y1="19" x2="12" y2="5"></line>
					<polyline points="5 12 12 5 19 12"></polyline>
				</svg>
				Pemasukan
			</a>
			<a href="/infaq?type=pengeluaran" class="quick-action-btn expense-btn">
				<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="12" y1="5" x2="12" y2="19"></line>
					<polyline points="19 12 12 19 5 12"></polyline>
				</svg>
				Pengeluaran
			</a>
		</div>
	{/if}

	<!-- Recent Transactions -->
	<div class="section-header">
		<h2 class="section-title">Transaksi Terakhir</h2>
		<a href="/laporan" class="section-link">Lihat Semua →</a>
	</div>

	{#if recentTransactions.length === 0}
		<div class="empty-state">
			<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
			</svg>
			<p>Belum ada transaksi</p>
		</div>
	{:else}
		<div class="transaction-list">
			{#each recentTransactions as tx}
				<div class="transaction-item">
					<div class="transaction-icon" class:income={tx.type === 'infaq_masuk'} class:expense={tx.type === 'pengeluaran'}>
						{#if tx.type === 'infaq_masuk'}
							<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<line x1="12" y1="19" x2="12" y2="5"></line>
								<polyline points="5 12 12 5 19 12"></polyline>
							</svg>
						{:else}
							<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<line x1="12" y1="5" x2="12" y2="19"></line>
								<polyline points="19 12 12 19 5 12"></polyline>
							</svg>
						{/if}
					</div>
					<div class="transaction-info">
						<div class="transaction-desc">
							{tx.description || (tx.type === 'infaq_masuk' ? 'Infaq Masuk' : 'Pengeluaran')}
							{#if tx.is_penyisihan}
								<span class="badge badge-private">Privat</span>
							{/if}
						</div>
						<div class="transaction-date">{formatDate(tx.transaction_date)}</div>
					</div>
					<div class="transaction-right">
						<div class="transaction-amount" class:income={tx.type === 'infaq_masuk'} class:expense={tx.type === 'pengeluaran'}>
							{tx.type === 'infaq_masuk' ? '+' : '-'}{formatCurrency(tx.amount)}
						</div>
						{#if $isAdmin}
							<button class="btn-action share" on:click={() => sendWhatsApp(tx)} style="padding: 0; font-size: 0.75rem; display: flex; align-items: center; gap: 4px;" title="Kirim WA">
								<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 20 20" fill="currentColor">
									<path d="M10.002,0C4.484,0 0,4.48535 0,10C0,12.18666 0.705,14.21526 1.904,15.86076L0.658,19.57687L4.501,18.3485C6.082,19.39482 7.969,20 10.002,20C15.515,20 20,15.51465 20,10C20,4.48535 15.515,0 10.002,0M15.821,14.12124C15.58,14.80344 14.622,15.36761 13.858,15.53266C13.335,15.64369 12.653,15.73172 10.355,14.77943C7.774,13.71011 4.19,9.90097 4.19,7.36621C4.19,6.07582 4.934,4.57337 6.235,4.57337C6.861,4.57337 6.999,4.58538 7.205,5.07952C7.446,5.6617 8.034,7.09613 8.104,7.24317C8.393,7.84635 7.81,8.19946 7.387,8.72462C7.252,8.88266 7.099,9.05372 7.27,9.3478C7.44,9.63589 8.028,10.59418 8.892,11.36341C10.008,12.35771 10.913,12.6748 11.237,12.80984C11.478,12.90987 11.766,12.88687 11.942,12.69881C12.165,12.45774 12.442,12.05762 12.724,11.6635C12.923,11.38141 13.176,11.3464 13.441,11.44643C13.62,11.50845 15.895,12.56477 15.991,12.73382C16.062,12.85686 16.062,13.43903 15.821,14.12124"/>
								</svg>
							</button>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
{/if}

<style>
	.home-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1.5rem;
	}

	.greeting-text {
		font-size: 0.875rem;
		color: var(--text-muted);
		margin-bottom: 0.125rem;
	}

	.greeting-name {
		font-size: 1.375rem;
		font-weight: 700;
	}

	.logout-btn {
		background: none;
		border: none;
		cursor: pointer;
		padding: 0.5rem;
		color: var(--text-muted);
		transition: color 0.2s;
	}

	.logout-btn:hover {
		color: var(--danger);
	}

	.avatar {
		width: 44px;
		height: 44px;
		border-radius: 50%;
		background: var(--primary-gradient);
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1.125rem;
		font-weight: 700;
		box-shadow: 0 4px 12px rgba(0, 200, 83, 0.2);
	}

	.penyisihan-card {
		display: flex;
		align-items: center;
		gap: 0.875rem;
		background: var(--secondary-light);
		border-radius: var(--radius-lg);
		padding: 1rem 1.25rem;
		margin-bottom: 1.5rem;
	}

	.penyisihan-icon {
		font-size: 1.5rem;
	}

	.penyisihan-info {
		flex: 1;
	}

	.penyisihan-label {
		font-size: 0.75rem;
		font-weight: 500;
		color: var(--secondary);
		text-transform: uppercase;
		letter-spacing: 0.03em;
	}

	.penyisihan-value {
		font-size: 1.125rem;
		font-weight: 700;
		color: var(--secondary);
	}
</style>
