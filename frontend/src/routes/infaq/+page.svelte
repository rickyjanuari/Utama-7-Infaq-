<script lang="ts">
	import { page } from '$app/stores';
	import { supabase, type Transaction } from '$lib/supabase';
	import { auth, canViewPenyisihan } from '$lib/stores/auth';
	import { syncToGoogleSheets } from '$lib/sheets';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import html2canvas from 'html2canvas';
	import ReceiptCard from '$lib/components/ReceiptCard.svelte';

	let type: 'infaq_masuk' | 'pengeluaran' = 'infaq_masuk';
	let amount = '';
	let penyisihanAmount = '';
	let description = '';
	let category = 'umum';
	let transactionDate = new Date().toISOString().split('T')[0];
	let isPenyisihanExpense = false; // For pengeluaran: deduct from penyisihan fund
	let loading = false;
	let error = '';
	let success = '';
	// Santunan metadata
	let studentName = '';
	let studentClass = '';
	let parentRep = '';

	// Success Modal State
	let showSuccessModal = false;
	let lastTransaction: Transaction | null = null;

	const categories = [
		{ value: 'umum', label: 'Umum' },
		{ value: 'infaq_jumat', label: "Infaq Jum'at" },
		{ value: 'infaq_maulid', label: 'Infaq Maulid' },
		{ value: 'santunan', label: 'Santunan' },
		{ value: 'infaq_baznas', label: 'Infaq Baznas' },
		{ value: 'taziyah', label: 'Taziyah' },
		{ value: 'pembelian', label: 'Pembelian' },
		{ value: 'donasi', label: 'Donasi' },
		{ value: 'jenguk', label: 'Jenguk' },
		{ value: 'gaji', label: 'Gaji/Honor' },
		{ value: 'listrik', label: 'Listrik/Air' },
		{ value: 'operasional', label: 'Operasional' },
		{ value: 'kegiatan', label: 'Kegiatan' },
		{ value: 'sedekah', label: 'Sedekah' },
		{ value: 'lainnya', label: 'Lainnya' }
	];

	onMount(() => {
		const urlType = $page.url.searchParams.get('type');
		if (urlType === 'pengeluaran') {
			type = 'pengeluaran';
		}
	});

	// Reset penyisihan fields when type changes
	$: if (type === 'infaq_masuk') {
		isPenyisihanExpense = false;
	} else {
		penyisihanAmount = '';
	}

	async function handleSubmit() {
		const amountNum = parseFloat(amount.replace(/[^0-9]/g, ''));
		const penyisihanNum = penyisihanAmount ? parseFloat(penyisihanAmount.replace(/[^0-9]/g, '')) : 0;
		
		if (!amountNum || amountNum <= 0) {
			error = 'Jumlah harus lebih dari 0';
			return;
		}

		if (type === 'infaq_masuk' && penyisihanNum > amountNum) {
			error = 'Penyisihan tidak boleh lebih besar dari jumlah infaq';
			return;
		}

		if (!transactionDate) {
			error = 'Tanggal harus diisi';
			return;
		}

		loading = true;
		error = '';
		success = '';

		try {
			// Declare variables outside the if block so they are accessible later
			let mainData, insertData;

			if (type === 'infaq_masuk' && penyisihanNum > 0) {
				// Infaq dengan penyisihan: buat 2 transaksi
				const mainAmount = amountNum - penyisihanNum;

				// 1. Transaksi utama (yang tampil di laporan umum)
				if (mainAmount > 0) {
					const { data, error: mainError } = await supabase
						.from('transactions')
						.insert({
							user_id: $auth.user?.id,
							type: 'infaq_masuk',
							amount: mainAmount,
							description: description || 'Infaq Masuk',
							transaction_date: transactionDate,
							category,
							is_penyisihan: false,
							metadata: category === 'santunan' ? { student_name: studentName, student_class: studentClass, parent_rep: parentRep } : {}
						})
						.select()
						.single();
					if (mainError) throw mainError;
					mainData = data;
					
					if (mainData) {
						syncToGoogleSheets('INSERT', {
							...mainData,
							user_name: $auth.user?.name || ''
						});
					}
				}

				// 2. Transaksi penyisihan (hanya tampil di laporan privat)
				const { data: penyisihanData, error: penyisihanError } = await supabase
					.from('transactions')
					.insert({
						user_id: $auth.user?.id,
						type: 'infaq_masuk',
						amount: penyisihanNum,
						description: `Penyisihan: ${description || 'Infaq'}`,
						transaction_date: transactionDate,
						category,
						is_penyisihan: true,
						metadata: category === 'santunan' ? { student_name: studentName, student_class: studentClass, parent_rep: parentRep } : {}
					})
					.select()
					.single();
				if (penyisihanError) throw penyisihanError;
				
				if (penyisihanData) {
					syncToGoogleSheets('INSERT', {
						...penyisihanData,
						user_name: $auth.user?.name || ''
					});
				}

				success = `Infaq Rp ${formatNumber(amountNum)} berhasil! (Penyisihan: Rp ${formatNumber(penyisihanNum)})`;
			} else {
				// Transaksi biasa (pengeluaran atau infaq tanpa penyisihan)
				const { data, error: insertError } = await supabase
					.from('transactions')
					.insert({
						user_id: $auth.user?.id,
						type,
						amount: amountNum,
						description,
						transaction_date: transactionDate,
						category,
						is_penyisihan: type === 'pengeluaran' ? isPenyisihanExpense : false,
						metadata: category === 'santunan' ? { student_name: studentName, student_class: studentClass, parent_rep: parentRep } : {}
					})
					.select()
					.single();

				if (insertError) throw insertError;
				insertData = data;
				
				if (insertData) {
					syncToGoogleSheets('INSERT', {
						...insertData,
						user_name: $auth.user?.name || ''
					});
				}
				
				if (type === 'pengeluaran' && isPenyisihanExpense) {
					success = 'Pengeluaran dari dana penyisihan berhasil dicatat!';
				} else {
					success = type === 'infaq_masuk' ? 'Infaq berhasil dicatat!' : 'Pengeluaran berhasil dicatat!';
				}
			}

			amount = '';
			penyisihanAmount = '';
			description = '';
			category = 'umum';
			isPenyisihanExpense = false;
			studentName = '';
			studentClass = '';
			parentRep = '';
			
			// Show success modal instead of redirecting
			showSuccessModal = true;
			// Use the main inserted data for the receipt
			// If it was split (penyisihan), we use the main part or the last inserted one
			// For simplicity, we use the last available data object
			const rawData = type === 'infaq_masuk' && penyisihanNum > 0 ? mainData : (insertData || mainData);
			
			if (rawData) {
				lastTransaction = rawData as Transaction;
			}
		} catch (e: unknown) {
			const err = e as { message?: string };
			error = err.message || 'Gagal menyimpan transaksi';
		} finally {
			loading = false;
		}
	}

	function sendWhatsApp() {
		if (!lastTransaction) return;
		
		const text = `*Kuitansi Digital - INFAQ UTUH*%0A%0A` +
			`Tanggal : ${formatDate(lastTransaction.transaction_date)} (%23${lastTransaction.id.substring(0, 4)})%0A` +
			`Tipe : ${lastTransaction.type === 'infaq_masuk' ? 'Infaq Masuk' : 'Pengeluaran'}%0A` +
			`Jumlah : Rp ${formatNumber(Number(lastTransaction.amount))}%0A` +
			`Kategori : ${lastTransaction.category || 'Umum'}%0A` +
			`Keterangan : ${lastTransaction.description || '-'}%0A%0A` +
			`Terima kasih telah berpartisipasi. Semoga berkah.`;
			
		window.open(`https://wa.me/?text=${text}`, '_blank');
	}

	function formatDate(dateStr: string) {
		return new Date(dateStr).toLocaleDateString('id-ID', {
			day: 'numeric',
			month: 'long',
			year: 'numeric'
		});
	}

	async function captureReceipt(): Promise<Blob | null> {
		const element = document.getElementById('receipt-card-container');
		if (!element) return null;
		
		try {
			const canvas = await html2canvas(element, {
				scale: 2,
				backgroundColor: '#ffffff',
				useCORS: true // for logo if needed
			} as any);
			
			return new Promise(resolve => {
				canvas.toBlob(blob => resolve(blob), 'image/png');
			});
		} catch (e) {
			console.error('Capture failed', e);
			return null;
		}
	}

	async function downloadReceipt() {
		const blob = await captureReceipt();
		if (!blob) return;
		
		const url = URL.createObjectURL(blob);
		const a = document.createElement('a');
		a.href = url;
		a.download = `kwitansi-${lastTransaction?.id.substring(0,6) || 'infaq'}.png`;
		a.click();
		URL.revokeObjectURL(url);
	}

	async function shareReceipt() {
		const blob = await captureReceipt();
		if (!blob) return;

		const file = new File([blob], `kwitansi-${lastTransaction?.id.substring(0,6) || 'infaq'}.png`, { type: 'image/png' });

		if (navigator.share && navigator.canShare && navigator.canShare({ files: [file] })) {
			try {
				await navigator.share({
					files: [file],
					title: 'Kwitansi INFAQ UTUH',
					text: 'Berikut adalah kwitansi infaq Anda.'
				});
			} catch (e) {
				console.error('Share failed', e);
			}
		} else {
			downloadReceipt();
		}
	}

	function closeSuccess() {
		showSuccessModal = false;
		goto('/');
	}

	function formatNumber(num: number): string {
		return new Intl.NumberFormat('id-ID').format(num);
	}

	function formatAmount(e: Event) {
		const input = e.target as HTMLInputElement;
		const value = input.value.replace(/[^0-9]/g, '');
		if (value) {
			amount = new Intl.NumberFormat('id-ID').format(parseInt(value));
		} else {
			amount = '';
		}
	}

	function formatPenyisihan(e: Event) {
		const input = e.target as HTMLInputElement;
		const value = input.value.replace(/[^0-9]/g, '');
		if (value) {
			penyisihanAmount = new Intl.NumberFormat('id-ID').format(parseInt(value));
		} else {
			penyisihanAmount = '';
		}
	}

	$: amountNum = amount ? parseFloat(amount.replace(/[^0-9]/g, '')) : 0;
	$: penyisihanNum = penyisihanAmount ? parseFloat(penyisihanAmount.replace(/[^0-9]/g, '')) : 0;
	$: netAmount = amountNum - penyisihanNum;
</script>

<div class="page-header">
	<h1 class="page-title">{type === 'infaq_masuk' ? 'Input Infaq' : 'Input Pengeluaran'}</h1>
</div>

<div class="type-toggle">
	<button
		class="toggle-btn"
		class:active={type === 'infaq_masuk'}
		on:click={() => type = 'infaq_masuk'}
	>
		<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
		</svg>
		Infaq Masuk
	</button>
	<button
		class="toggle-btn"
		class:active={type === 'pengeluaran'}
		on:click={() => type = 'pengeluaran'}
	>
		<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4" />
		</svg>
		Pengeluaran
	</button>
</div>

<form class="card" on:submit|preventDefault={handleSubmit}>
	{#if error}
		<div class="message error">{error}</div>
	{/if}
	{#if success}
		<div class="message success">{success}</div>
	{/if}

	<div class="form-group">
		<label for="amount" class="form-label">
			{type === 'infaq_masuk' ? 'Jumlah Infaq (Rp)' : 'Jumlah Pengeluaran (Rp)'}
		</label>
		<input
			type="text"
			id="amount"
			class="form-input amount-input"
			placeholder="0"
			bind:value={amount}
			on:input={formatAmount}
			disabled={loading}
			inputmode="numeric"
		/>
	</div>

	{#if type === 'infaq_masuk' && $canViewPenyisihan}
		<div class="form-group">
			<label for="penyisihan" class="form-label">
				Penyisihan (Rp) 
				<span style="font-weight: 400; color: var(--text-muted);">- opsional</span>
			</label>
			<input
				type="text"
				id="penyisihan"
				class="form-input"
				placeholder="0"
				bind:value={penyisihanAmount}
				on:input={formatPenyisihan}
				disabled={loading}
				inputmode="numeric"
			/>
			<small style="color: var(--text-muted); display: block; margin-top: 0.5rem;">
				Akan otomatis dipotong dari laporan umum
			</small>
		</div>

		{#if penyisihanNum > 0 && amountNum > 0}
			<div class="summary-box">
				<div class="summary-row">
					<span>Total Infaq:</span>
					<span class="income">Rp {formatNumber(amountNum)}</span>
				</div>
				<div class="summary-row">
					<span>Penyisihan:</span>
					<span class="expense">- Rp {formatNumber(penyisihanNum)}</span>
				</div>
				<div class="summary-row total">
					<span>Masuk Laporan Umum:</span>
					<span>Rp {formatNumber(netAmount)}</span>
				</div>
			</div>
		{/if}
	{/if}

	{#if type === 'pengeluaran' && $canViewPenyisihan}
		<div class="form-group">
			<label class="form-label">Sumber Dana</label>
			<div class="source-toggle">
				<button
					type="button"
					class="source-btn"
					class:active={!isPenyisihanExpense}
					on:click={() => isPenyisihanExpense = false}
				>
					Dana Umum
				</button>
				<button
					type="button"
					class="source-btn penyisihan"
					class:active={isPenyisihanExpense}
					on:click={() => isPenyisihanExpense = true}
				>
					Dana Penyisihan
				</button>
			</div>
			{#if isPenyisihanExpense}
				<small style="color: var(--secondary); display: block; margin-top: 0.5rem;">
					⚠️ Akan mengurangi saldo penyisihan (privat)
				</small>
			{/if}
		</div>
	{/if}

	<div class="form-group">
		<label for="date" class="form-label">Tanggal</label>
		<input
			type="date"
			id="date"
			class="form-input"
			bind:value={transactionDate}
			disabled={loading}
		/>
	</div>

	<div class="form-group">
		<label for="category" class="form-label">Kategori</label>
		<select
			id="category"
			class="form-input"
			bind:value={category}
			disabled={loading}
		>
			{#each categories as cat}
				<option value={cat.value}>{cat.label}</option>
			{/each}
		</select>
	</div>

	{#if category === 'santunan'}
		<div class="card" style="background: var(--bg-tertiary); margin-bottom: 1.5rem; border: 1px solid var(--border);">
			<h3 style="font-size: 0.9rem; font-weight: 600; margin-bottom: 1rem; color: var(--primary);">Detail Santunan</h3>
			
			<div class="form-group">
				<label for="studentName" class="form-label">Nama Siswa</label>
				<input
					type="text"
					id="studentName"
					class="form-input"
					placeholder="Nama Lengkap Siswa"
					bind:value={studentName}
					disabled={loading}
				/>
			</div>

			<div class="form-group">
				<label for="studentClass" class="form-label">Kelas</label>
				<input
					type="text"
					id="studentClass"
					class="form-input"
					placeholder="Contoh: 7A"
					bind:value={studentClass}
					disabled={loading}
				/>
			</div>

			<div class="form-group">
				<label for="parentRep" class="form-label">Perwakilan Orang Tua</label>
				<input
					type="text"
					id="parentRep"
					class="form-input"
					placeholder="Nama Wali / Orang Tua"
					bind:value={parentRep}
					disabled={loading}
				/>
			</div>
		</div>
	{/if}

	<div class="form-group">
		<label for="description" class="form-label">Keterangan</label>
		<input
			type="text"
			id="description"
			class="form-input"
			placeholder="Contoh: Infaq Jumat"
			bind:value={description}
			disabled={loading}
		/>
	</div>

	<button type="submit" class="btn btn-block" class:btn-primary={type === 'infaq_masuk'} class:btn-danger={type === 'pengeluaran'} disabled={loading}>
		{#if loading}
			<div class="spinner" style="width: 20px; height: 20px; border-width: 2px;"></div>
		{:else}
			Simpan {type === 'infaq_masuk' ? 'Infaq' : 'Pengeluaran'}
		{/if}
	</button>
</form>

{#if showSuccessModal}
	<div class="modal-overlay">
		<div class="modal success-modal">
			<div class="success-icon">
				<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" fill="none" viewBox="0 0 24 24" stroke="currentColor">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
				</svg>
			</div>
			<h3>Transaksi Berhasil!</h3>
			<p>Data telah tersimpan di sistem.</p>
			
			{#if lastTransaction}
				<div style="margin: 1.5rem 0;" id="receipt-card-container">
					<ReceiptCard transaction={lastTransaction} recorderName={$auth.user?.name || ''} />
				</div>
			{/if}

			<div class="action-buttons">
				<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 0.5rem;">
					<button class="btn btn-secondary" on:click={downloadReceipt}>
						<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
						</svg>
						Simpan
					</button>
					<button class="btn btn-primary" on:click={shareReceipt}>
						<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
						</svg>
						Share Gambar
					</button>
				</div>
				<button class="btn btn-primary btn-block wa-btn" on:click={sendWhatsApp}>
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
						<path d="M10.002,0C4.484,0 0,4.48535 0,10C0,12.18666 0.705,14.21526 1.904,15.86076L0.658,19.57687L4.501,18.3485C6.082,19.39482 7.969,20 10.002,20C15.515,20 20,15.51465 20,10C20,4.48535 15.515,0 10.002,0M15.821,14.12124C15.58,14.80344 14.622,15.36761 13.858,15.53266C13.335,15.64369 12.653,15.73172 10.355,14.77943C7.774,13.71011 4.19,9.90097 4.19,7.36621C4.19,6.07582 4.934,4.57337 6.235,4.57337C6.861,4.57337 6.999,4.58538 7.205,5.07952C7.446,5.6617 8.034,7.09613 8.104,7.24317C8.393,7.84635 7.81,8.19946 7.387,8.72462C7.252,8.88266 7.099,9.05372 7.27,9.3478C7.44,9.63589 8.028,10.59418 8.892,11.36341C10.008,12.35771 10.913,12.6748 11.237,12.80984C11.478,12.90987 11.766,12.88687 11.942,12.69881C12.165,12.45774 12.442,12.05762 12.724,11.6635C12.923,11.38141 13.176,11.3464 13.441,11.44643C13.62,11.50845 15.895,12.56477 15.991,12.73382C16.062,12.85686 16.062,13.43903 15.821,14.12124"/>
					</svg>
					Kirim Teks WA
				</button>
				<button class="btn btn-secondary btn-block" on:click={closeSuccess}>
					Selesai & Kembali
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.type-toggle {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.5rem;
		margin-bottom: 1.5rem;
	}

	.toggle-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 0.75rem;
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--bg-secondary);
		color: var(--text-secondary);
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.toggle-btn.active {
		border-color: var(--primary);
		background: var(--primary-light);
		color: var(--primary);
	}

	.amount-input {
		font-size: 1.5rem;
		font-weight: 600;
		text-align: center;
	}

	.message {
		padding: 0.75rem 1rem;
		border-radius: var(--radius-md);
		margin-bottom: 1rem;
		font-size: 0.875rem;
	}

	.message.error {
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid var(--danger);
		color: var(--danger);
	}

	.message.success {
		background: rgba(34, 197, 94, 0.1);
		border: 1px solid var(--success);
		color: var(--success);
	}

	.summary-box {
		background: var(--bg-tertiary);
		border-radius: var(--radius-md);
		padding: 1rem;
		margin-bottom: 1rem;
	}

	.summary-row {
		display: flex;
		justify-content: space-between;
		padding: 0.375rem 0;
		font-size: 0.9375rem;
	}

	.summary-row.total {
		border-top: 1px solid var(--border);
		margin-top: 0.5rem;
		padding-top: 0.75rem;
		font-weight: 600;
	}

	.income {
		color: var(--success);
	}

	.expense {
		color: var(--danger);
	}

	.source-toggle {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.5rem;
	}

	.source-btn {
		padding: 0.75rem;
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--bg-tertiary);
		color: var(--text-secondary);
		font-size: 0.875rem;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.source-btn.active {
		border-color: var(--primary);
		background: var(--primary-light);
		color: var(--primary);
	}

	.source-btn.penyisihan.active {
		border-color: var(--secondary);
		background: rgba(99, 102, 241, 0.1);
		color: var(--secondary);
	}

	.success-modal {
		text-align: center;
		padding: 2rem;
	}

	.success-icon {
		width: 80px;
		height: 80px;
		background: var(--success-light);
		color: var(--success);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		margin: 0 auto 1.5rem;
	}

	.wa-btn {
		background: #25D366;
		color: white;
		box-shadow: 0 4px 12px rgba(37, 211, 102, 0.3);
		margin-bottom: 0.75rem;
	}

	.wa-btn:hover {
		background: #128C7E;
	}
	
	.action-buttons {
		margin-top: 1.5rem;
	}
</style>
