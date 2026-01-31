<script lang="ts">
	import { supabase, type Transaction } from '$lib/supabase';
	import { syncToGoogleSheets } from '$lib/sheets';
	import { isAdmin } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import jsPDF from 'jspdf';
	import autoTable from 'jspdf-autotable';

	let transactions: Transaction[] = [];
	let loading = true;
	let error = '';
	let initialPenyisihan = 0;

	// Edit modal state
	let showEditModal = false;
	let editingTx: Transaction | null = null;
	let editAmount = '';
	let editDescription = '';
	let editDate = '';
	let editType: 'infaq_masuk' | 'pengeluaran' = 'infaq_masuk';
	let editCategory = 'umum';
	let editLoading = false;
	let editError = '';

	const categories = [
		{ value: 'umum', label: 'Umum' },
		{ value: 'infaq_maulid', label: 'Infaq Maulid' },
		{ value: 'gaji', label: 'Gaji/Honor' },
		{ value: 'listrik', label: 'Listrik/Air' },
		{ value: 'operasional', label: 'Operasional' },
		{ value: 'kegiatan', label: 'Kegiatan' },
		{ value: 'sedekah', label: 'Sedekah' },
		{ value: 'lainnya', label: 'Lainnya' }
	];

	onMount(async () => {
		await loadData();
	});

	async function loadData() {
		loading = true;
		try {
			// Get initial penyisihan from profiles
			const { data: profileData } = await supabase
				.from('profiles')
				.select('initial_penyisihan')
				.limit(1);
			
			initialPenyisihan = profileData?.[0]?.initial_penyisihan || 0;

			const { data, error: fetchError } = await supabase
				.from('transactions')
				.select(`
					*,
					profiles:user_id (name)
				`)
				.eq('is_penyisihan', true)
				.order('transaction_date', { ascending: false })
				.order('created_at', { ascending: false });

			if (fetchError) throw fetchError;

			transactions = (data || []).map(t => ({
				...t,
				user_name: t.profiles?.name || 'Unknown'
			})).sort((a, b) => {
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

	function openEditModal(tx: Transaction) {
		editingTx = tx;
		editAmount = formatNumber(Number(tx.amount));
		editDescription = tx.description || '';
		editDate = tx.transaction_date;
		editType = tx.type as 'infaq_masuk' | 'pengeluaran';
		editCategory = tx.category || 'umum';
		editError = '';
		showEditModal = true;
	}

	function closeEditModal() {
		showEditModal = false;
		editingTx = null;
	}

	async function handleEdit() {
		if (!editingTx) return;
		
		const amountNum = parseFloat(editAmount.replace(/[^0-9]/g, ''));
		if (!amountNum || amountNum <= 0) {
			editError = 'Jumlah harus lebih dari 0';
			return;
		}

		editLoading = true;
		editError = '';

		try {
			const { data: updatedData, error: updateError } = await supabase
				.from('transactions')
				.update({
					amount: amountNum,
					description: editDescription,
					transaction_date: editDate,
					type: editType,
					category: editCategory
				})
				.eq('id', editingTx.id)
				.select()
				.maybeSingle();

			if (updateError) throw updateError;

			if (updatedData) {
				syncToGoogleSheets('UPDATE', {
					...updatedData,
					user_name: editingTx.user_name || ''
				});
			}

			transactions = transactions.map(t => 
				t.id === editingTx!.id 
					? { ...t, amount: amountNum, description: editDescription, transaction_date: editDate, type: editType, category: editCategory }
					: t
			).sort((a, b) => {
				const dateA = new Date(a.transaction_date).getTime();
				const dateB = new Date(b.transaction_date).getTime();
				if (dateB !== dateA) return dateB - dateA;
				return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
			});

			closeEditModal();
		} catch (e: unknown) {
			const err = e as { message?: string };
			editError = err.message || 'Gagal mengupdate transaksi';
		} finally {
			editLoading = false;
		}
	}

	async function handleDelete(tx: Transaction) {
		if (!confirm('Yakin hapus transaksi penyisihan ini?')) return;
		
		try {
			const { error: delError } = await supabase
				.from('transactions')
				.delete()
				.eq('id', tx.id);

			if (delError) throw delError;
			
			syncToGoogleSheets('DELETE', tx);
			transactions = transactions.filter(t => t.id !== tx.id);
		} catch (e: unknown) {
			const err = e as { message?: string };
			alert('Gagal menghapus: ' + (err.message || 'Unknown error'));
		}
	}

	function formatNumber(num: number): string {
		return new Intl.NumberFormat('id-ID').format(num);
	}

	function formatEditAmount(e: Event) {
		const input = e.target as HTMLInputElement;
		const value = input.value.replace(/[^0-9]/g, '');
		if (value) {
			editAmount = new Intl.NumberFormat('id-ID').format(parseInt(value));
		} else {
			editAmount = '';
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

	// Export PDF
	function exportPDF() {
		const doc = new jsPDF();
		
		// Header
		doc.setFontSize(18);
		doc.text('Laporan Dana Penyisihan (Privat)', 14, 20);
		doc.setFontSize(10);
		doc.text(`Dicetak pada: ${new Date().toLocaleString('id-ID')}`, 14, 28);
		
		// Summary
		doc.text(`Saldo Penyisihan: ${formatCurrency(totalPenyisihan)}`, 14, 38);
		doc.text(`Total Masuk: ${formatCurrency(totalMasuk)}`, 14, 43);
		doc.text(`Total Digunakan: ${formatCurrency(totalKeluar)}`, 14, 48);

		// Table
		const tableData = transactions.map(t => [
			formatDate(t.transaction_date),
			t.type === 'infaq_masuk' ? 'Masuk' : 'Keluar',
			t.description || '-',
			t.category || 'Umum',
			formatCurrency(Number(t.amount))
		]);

		autoTable(doc, {
			startY: 55,
			head: [['Tanggal', 'Tipe', 'Keterangan', 'Kategori', 'Jumlah']],
			body: tableData,
			headStyles: { fillColor: [99, 102, 241] }, // Indigo color for private
			theme: 'grid',
			styles: { fontSize: 8 },
			columnStyles: {
				4: { halign: 'right' }
			}
		});

		doc.save(`Laporan_Penyisihan_${new Date().toISOString().split('T')[0]}.pdf`);
	}

	// Calculate totals
	$: totalMasuk = transactions.filter(t => t.type === 'infaq_masuk').reduce((sum, t) => sum + Number(t.amount), 0);
	$: totalKeluar = transactions.filter(t => t.type === 'pengeluaran').reduce((sum, t) => sum + Number(t.amount), 0);
	$: totalPenyisihan = initialPenyisihan + totalMasuk - totalKeluar;
</script>

<div class="page-header">
	<div>
		<h1 class="page-title">Dana Penyisihan</h1>
		<span class="badge badge-private">Privat</span>
	</div>
	<button class="btn btn-sm btn-secondary" on:click={exportPDF}>
		<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="margin-right: 0.25rem;">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
		</svg>
		PDF
	</button>
</div>

<div class="info-banner">
	<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
		<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
	</svg>
	<span>Laporan ini hanya bisa diakses oleh guru tertentu</span>
</div>

<!-- Summary Cards -->
<div class="summary-cards">
	<div class="summary-card balance purple">
		<p class="summary-label">Saldo Penyisihan</p>
		<p class="summary-value">{formatCurrency(totalPenyisihan)}</p>
		{#if initialPenyisihan > 0}
			<p class="summary-note">Termasuk saldo awal {formatCurrency(initialPenyisihan)}</p>
		{/if}
	</div>
	<div class="summary-row">
		<div class="summary-card income">
			<p class="summary-label">Masuk</p>
			<p class="summary-value">{formatCurrency(totalMasuk)}</p>
		</div>
		<div class="summary-card expense">
			<p class="summary-label">Digunakan</p>
			<p class="summary-value">{formatCurrency(totalKeluar)}</p>
		</div>
	</div>
</div>

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
		<h2 class="section-title">Riwayat Penyisihan</h2>
	</div>

	{#if transactions.length === 0}
		<div class="empty-state">
			<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
			</svg>
			<p>Belum ada dana penyisihan</p>
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
							{tx.description || (tx.type === 'infaq_masuk' ? 'Penyisihan Masuk' : 'Penggunaan')}
							{#if tx.category && tx.category !== 'umum'}
								<span class="category-badge">{tx.category}</span>
							{/if}
						</div>
						<div class="transaction-date">{formatDate(tx.transaction_date)} • {tx.user_name}</div>
					</div>
					<div style="display: flex; flex-direction: column; align-items: flex-end; gap: 0.25rem;">
						<div class="transaction-amount" class:income={tx.type === 'infaq_masuk'} class:expense={tx.type === 'pengeluaran'}>
							{tx.type === 'infaq_masuk' ? '+' : '-'}{formatCurrency(tx.amount)}
						</div>
						{#if $isAdmin}
							<div class="action-buttons">
								<button class="btn-action edit" on:click={() => openEditModal(tx)} title="Edit">
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
									</svg>
								</button>
								<button class="btn-action delete" on:click={() => handleDelete(tx)} title="Hapus">
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
									</svg>
								</button>
							</div>
						{/if}
					</div>
				</div>
			{/each}
		</div>
	{/if}
{/if}

<!-- Edit Modal -->
{#if showEditModal && editingTx}
	<div class="modal-overlay" on:click={closeEditModal} on:keydown={(e) => e.key === 'Escape' && closeEditModal()} role="button" tabindex="0">
		<div class="modal" on:click|stopPropagation role="dialog" aria-modal="true">
			<h2 class="modal-title">Edit Penyisihan</h2>
			
			<form on:submit|preventDefault={handleEdit}>
				{#if editError}
					<div class="message error">{editError}</div>
				{/if}

				<div class="form-group">
					<label class="form-label">Tipe</label>
					<div class="type-toggle">
						<button type="button" class="toggle-btn" class:active={editType === 'infaq_masuk'} on:click={() => editType = 'infaq_masuk'}>
							Masuk
						</button>
						<button type="button" class="toggle-btn" class:active={editType === 'pengeluaran'} on:click={() => editType = 'pengeluaran'}>
							Digunakan
						</button>
					</div>
				</div>

				<div class="form-group">
					<label for="editAmount" class="form-label">Jumlah (Rp)</label>
					<input type="text" id="editAmount" class="form-input" bind:value={editAmount} on:input={formatEditAmount} disabled={editLoading} inputmode="numeric" />
				</div>

				<div class="form-group">
					<label for="editDate" class="form-label">Tanggal</label>
					<input type="date" id="editDate" class="form-input" bind:value={editDate} disabled={editLoading} />
				</div>

				<div class="form-group">
					<label for="editCategory" class="form-label">Kategori</label>
					<select id="editCategory" class="form-input" bind:value={editCategory} disabled={editLoading}>
						{#each categories as cat}
							<option value={cat.value}>{cat.label}</option>
						{/each}
					</select>
				</div>

				<div class="form-group">
					<label for="editDescription" class="form-label">Keterangan</label>
					<input type="text" id="editDescription" class="form-input" bind:value={editDescription} disabled={editLoading} />
				</div>

				<div style="display: flex; gap: 0.75rem; margin-top: 1.5rem;">
					<button type="button" class="btn btn-secondary" style="flex: 1;" on:click={closeEditModal} disabled={editLoading}>
						Batal
					</button>
					<button type="submit" class="btn btn-primary" style="flex: 1;" disabled={editLoading}>
						{#if editLoading}
							<div class="spinner" style="width: 20px; height: 20px; border-width: 2px;"></div>
						{:else}
							Simpan
						{/if}
					</button>
				</div>
			</form>
		</div>
	</div>
{/if}

<style>
	.info-banner {
		display: flex;
		align-items: center;
		gap: 0.625rem;
		padding: 0.625rem 0.875rem;
		background: var(--secondary-light);
		border-radius: var(--radius-md);
		color: var(--secondary);
		font-size: 0.8125rem;
		font-weight: 500;
		margin-bottom: 1.25rem;
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
		margin-bottom: 0.75rem;
		padding: 1.25rem;
	}

	.summary-card.balance.purple {
		background: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%);
		color: white;
		box-shadow: 0 8px 24px rgba(99, 102, 241, 0.25);
	}

	.summary-card.balance.purple .summary-label {
		color: rgba(255,255,255,0.8);
	}

	.summary-card.balance.purple .summary-value {
		font-size: 1.5rem;
	}

	.summary-card.balance .summary-note {
		font-size: 0.75rem;
		color: rgba(255,255,255,0.7);
		margin-top: 0.25rem;
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
		margin-bottom: 0.875rem;
	}

	.section-title {
		font-size: 1rem;
		font-weight: 600;
	}

	.category-badge {
		display: inline-block;
		font-size: 0.625rem;
		font-weight: 600;
		text-transform: uppercase;
		background: rgba(99, 102, 241, 0.15);
		color: #6366F1;
		padding: 0.125rem 0.375rem;
		border-radius: var(--radius-sm);
		margin-left: 0.375rem;
		vertical-align: middle;
	}
</style>
