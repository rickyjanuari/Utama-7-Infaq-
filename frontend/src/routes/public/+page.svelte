<script lang="ts">
	import { supabase, type Transaction } from '$lib/supabase';
	import { onMount } from 'svelte';

	let transactions: Transaction[] = [];
	let loading = true;
	let error = '';
	let initialBalance = 0;
	let qrisUrl = '';
	
	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		error = '';
		try {
			// Get initial balance & QRIS
			const { data: profileData } = await supabase
				.from('profiles')
				.select('initial_balance, qris_url')
				.limit(1);
			
			initialBalance = profileData?.[0]?.initial_balance || 0;
			qrisUrl = profileData?.[0]?.qris_url || '';

			// Get ONLY non-penyisihan transactions (public)
			const { data: txData, error: txError } = await supabase
				.from('transactions')
				.select('id, transaction_date, type, amount, description, created_at')
				.eq('is_penyisihan', false)
				.order('transaction_date', { ascending: false })
				.order('created_at', { ascending: false });

			if (txError) throw txError;

			// We cast to any[] first then Transaction[] because we don't fetch all fields
			// but we know it's safe for display purposes here
			// Ensure strict sorting client-side as well
			transactions = ((txData as any[]) || []).sort((a, b) => {
				const dateA = new Date(a.transaction_date).getTime();
				const dateB = new Date(b.transaction_date).getTime();
				if (dateB !== dateA) return dateB - dateA;
				return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
			});
		} catch (e: unknown) {
			const err = e as { message?: string };
			error = err.message || 'Failed to load data';
		} finally {
			loading = false;
		}
	}

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
			month: 'short',
			year: 'numeric'
		});
	}

	// Calculate totals
	$: totalMasuk = transactions.filter(t => t.type === 'infaq_masuk').reduce((sum, t) => sum + Number(t.amount), 0);
	$: totalKeluar = transactions.filter(t => t.type === 'pengeluaran').reduce((sum, t) => sum + Number(t.amount), 0);
	$: totalSaldo = initialBalance + totalMasuk - totalKeluar;
</script>

<div class="public-page">
	<div class="container">
		<div class="page-header">
			<h1 class="page-title">Laporan Infaq</h1>
			<a href="/login" class="login-link">Login →</a>
		</div>

		<p class="page-subtitle">Laporan keuangan infaq yang transparan untuk umum</p>

		<!-- Summary Cards -->
		<div class="summary-cards">
			<div class="summary-card balance">
				<p class="summary-label">Total Saldo</p>
				<p class="summary-value">{formatCurrency(totalSaldo)}</p>
			</div>
			<div class="summary-row">
				<div class="summary-card income">
					<p class="summary-label">Pemasukan</p>
					<p class="summary-value">{formatCurrency(totalMasuk)}</p>
				</div>
				<div class="summary-card expense">
					<p class="summary-label">Pengeluaran</p>
					<p class="summary-value">{formatCurrency(totalKeluar)}</p>
				</div>
			</div>
		</div>

		<!-- QRIS Display -->
		{#if qrisUrl}
			<div class="card qris-card">
				<h3 class="qris-title">Scan QRIS Infaq</h3>
				<div class="qris-image-container">
					<img src={qrisUrl} alt="Kode QRIS Masjid" class="qris-image" />
				</div>
				<p class="qris-instruction">Scan menggunakan GoPay, OVO, Dana, LinkAja, atau Mobile Banking</p>
			</div>
		{/if}

		{#if loading}
			<div class="loader">
				<div class="spinner"></div>
			</div>
		{:else if error}
			<div class="card" style="text-align: center; color: var(--danger);">
				<p>{error}</p>
			</div>
		{:else}
			<div class="section-header">
				<h2 class="section-title">Riwayat Transaksi</h2>
				<span class="transaction-count">{transactions.length} transaksi</span>
			</div>

			{#if transactions.length === 0}
				<div class="empty-state">
					<p>Belum ada transaksi</p>
				</div>
			{:else}
				<div class="transaction-list">
					{#each transactions as tx}
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
								</div>
								<div class="transaction-date">{formatDate(tx.transaction_date)}</div>
							</div>
							<div class="transaction-amount" class:income={tx.type === 'infaq_masuk'} class:expense={tx.type === 'pengeluaran'}>
								{tx.type === 'infaq_masuk' ? '+' : '-'}{formatCurrency(tx.amount)}
							</div>
						</div>
					{/each}
				</div>
			{/if}
		{/if}

		<div class="footer">
			<p>Infaq App • Transparan & Terpercaya</p>
		</div>
	</div>
</div>

<style>
	.public-page {
		min-height: 100vh;
		background: var(--bg-primary);
		padding: 1rem 0 2rem;
	}

	.container {
		max-width: 480px;
		margin: 0 auto;
	}

	.page-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.5rem;
	}

	.page-title {
		font-size: 1.5rem;
		font-weight: 700;
	}

	.login-link {
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--primary);
		text-decoration: none;
	}

	.page-subtitle {
		font-size: 0.875rem;
		color: var(--text-muted);
		margin-bottom: 1.5rem;
	}

	.summary-cards {
		margin-bottom: 1.5rem;
	}

	.summary-card {
		background: var(--bg-card);
		border-radius: var(--radius-lg);
		padding: 1rem 1.25rem;
		box-shadow: var(--shadow-card);
	}

	.summary-card.balance {
		background: var(--primary-gradient);
		color: white;
		margin-bottom: 0.75rem;
		padding: 1.25rem;
	}

	.summary-card.balance .summary-label {
		color: rgba(255,255,255,0.8);
	}

	.summary-card.balance .summary-value {
		font-size: 1.5rem;
	}

	.summary-row {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
	}

	.summary-label {
		font-size: 0.75rem;
		font-weight: 500;
		color: var(--text-muted);
		text-transform: uppercase;
		letter-spacing: 0.03em;
		margin-bottom: 0.25rem;
	}

	.summary-value {
		font-size: 1.125rem;
		font-weight: 700;
	}

	.summary-card.income .summary-value {
		color: var(--income);
	}

	.summary-card.expense .summary-value {
		color: var(--expense);
	}

	.section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.875rem;
	}

	.section-title {
		font-size: 1rem;
		font-weight: 600;
	}

	.transaction-count {
		font-size: 0.75rem;
		color: var(--text-muted);
	}

	.footer {
		margin-top: 2rem;
		text-align: center;
		font-size: 0.75rem;
		color: var(--text-light);
	}

	.qris-card {
		text-align: center;
		margin-bottom: 1.5rem;
		padding: 1.5rem;
		background: white;
	}

	.qris-title {
		font-size: 1rem;
		font-weight: 700;
		margin-bottom: 1rem;
		color: var(--text-primary);
	}

	.qris-image-container {
		display: flex;
		justify-content: center;
		margin-bottom: 0.75rem;
	}

	.qris-image {
		max-width: 200px;
		width: 100%;
		border-radius: var(--radius-md);
		border: 1px solid var(--border);
	}

	.qris-instruction {
		font-size: 0.75rem;
		color: var(--text-muted);
	}
</style>
