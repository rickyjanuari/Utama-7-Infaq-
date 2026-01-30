<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { auth, isAdmin } from '$lib/stores/auth';
	import { read, utils } from 'xlsx';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	let fileInput: HTMLInputElement;
	let loading = false;
	let error = '';
	let success = '';
	let previewData: any[] = [];
	let isPenyisihan = false; // Checkbox for "Dana Penyisihan"
	let importProgress = 0;

	onMount(() => {
		if (!$isAdmin) {
			goto('/');
		}
	});

	async function handleFileUpload(e: Event) {
		const target = e.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (!file) return;

		loading = true;
		error = '';
		previewData = [];

		try {
			const data = await file.arrayBuffer();
			const workbook = read(data);
			const sheetName = workbook.SheetNames[0];
			const worksheet = workbook.Sheets[sheetName];
			
			// Parse to JSON
			const jsonData = utils.sheet_to_json(worksheet, { header: 1 });
			
			// Simple validation: check if meaningful data exists
			if (jsonData.length < 2) {
				throw new Error('File kosong atau format salah');
			}

			// Mapping logic (assuming standard columns or auto-detect)
			// Row 0 is header
			const headers = jsonData[0] as string[];
			const rows = jsonData.slice(1);

			previewData = rows.map((row: any) => ({
				date: parseDate(row[0]), // Column A: Date
				description: row[1] || 'Imported Transaction', // Column B: Desc
				amount: parseFloat(row[2]) || 0, // Column C: Amount
				type: row[3] && String(row[3]).toLowerCase().includes('keluar') ? 'pengeluaran' : 'infaq_masuk', // Column D: Type
				category: row[4] || 'umum' // Column E: Category
			})).filter(item => item.amount > 0 && item.date);

		} catch (e: unknown) {
			const err = e as { message?: string };
			error = err.message || 'Gagal membaca file excel';
		} finally {
			loading = false;
		}
	}

	function parseDate(excelDate: any): string {
		// Handle Excel serial date or string
		if (typeof excelDate === 'number') {
			const date = new Date(Math.round((excelDate - 25569) * 86400 * 1000));
			return date.toISOString().split('T')[0];
		}
		// Handle string "YYYY-MM-DD" or "DD/MM/YYYY"
		if (typeof excelDate === 'string') {
			if (excelDate.includes('/')) {
				const parts = excelDate.split('/');
				// Assume DD/MM/YYYY
				return `${parts[2]}-${parts[1]}-${parts[0]}`;
			}
			return excelDate;
		}
		return new Date().toISOString().split('T')[0];
	}

	async function processImport() {
		if (previewData.length === 0) return;

		if (!confirm(`Yakin import ${previewData.length} transaksi ke ${isPenyisihan ? 'DANA PENYISIHAN' : 'DANA UMUM'}?`)) return;

		loading = true;
		importProgress = 0;
		let successCount = 0;
		let failCount = 0;

		const total = previewData.length;

		for (let i = 0; i < total; i++) {
			const item = previewData[i];
			try {
				const { error: insertError } = await supabase
					.from('transactions')
					.insert({
						user_id: $auth.user?.id,
						type: item.type,
						amount: item.amount,
						description: item.description,
						transaction_date: item.date,
						category: item.category,
						is_penyisihan: isPenyisihan // Key requirement
					});

				if (insertError) throw insertError;
				successCount++;
			} catch (e) {
				console.error('Import failed row', i, e);
				failCount++;
			}
			importProgress = Math.round(((i + 1) / total) * 100);
		}

		success = `Import Selesai! Berhasil: ${successCount}, Gagal: ${failCount}`;
		previewData = [];
		loading = false;
		
		if (fileInput) fileInput.value = '';
	}
</script>

<div class="page-header">
	<h1 class="page-title">Import Transaksi</h1>
	<a href="/settings" class="back-link">← Kembali</a>
</div>

<div class="card">
	<div class="import-options">
		<div class="option-group">
			<label class="checkbox-label">
				<input type="checkbox" bind:checked={isPenyisihan} disabled={loading || previewData.length > 0} />
				<span class="checkbox-custom"></span>
				<span class="label-text">
					Import ke <strong>Dana Penyisihan</strong> (Privat)
				</span>
			</label>
			<p class="option-desc">
				{#if isPenyisihan}
					Data akan masuk sebagai saldo penyisihan dan tidak muncul di laporan publik.
				{:else}
					Data akan masuk ke saldo umum (laporan biasa).
				{/if}
			</p>
		</div>
	</div>

	<div class="upload-area">
		<input 
			type="file" 
			accept=".xlsx, .xls, .csv" 
			on:change={handleFileUpload} 
			disabled={loading}
			bind:this={fileInput}
		/>
		<p class="upload-hint">Upload file Excel (.xlsx). Format kolom: Tanggal | Keterangan | Jumlah | Tipe | Kategori</p>
	</div>

	{#if error}
		<div class="message error">{error}</div>
	{/if}

	{#if success}
		<div class="message success">{success}</div>
	{/if}

	{#if loading && previewData.length > 0}
		<div class="progress-bar">
			<div class="progress-fill" style="width: {importProgress}%"></div>
		</div>
		<p style="text-align: center; font-size: 0.875rem;">Mengimport {importProgress}%...</p>
	{/if}

	{#if previewData.length > 0 && !loading}
		<div class="preview-section">
			<h3>Preview ({previewData.length} data)</h3>
			<div class="table-responsive">
				<table>
					<thead>
						<tr>
							<th>Tanggal</th>
							<th>Keterangan</th>
							<th>Jumlah</th>
							<th>Tipe</th>
							<th>Kategori</th>
						</tr>
					</thead>
					<tbody>
						{#each previewData.slice(0, 5) as item}
							<tr>
								<td>{item.date}</td>
								<td>{item.description}</td>
								<td>Rp {new Intl.NumberFormat('id-ID').format(item.amount)}</td>
								<td>
									<span class="badge" class:income={item.type === 'infaq_masuk'} class:expense={item.type === 'pengeluaran'}>
										{item.type === 'infaq_masuk' ? 'Masuk' : 'Keluar'}
									</span>
								</td>
								<td>{item.category}</td>
							</tr>
						{/each}
						{#if previewData.length > 5}
							<tr>
								<td colspan="5" style="text-align: center; color: var(--text-muted);">
									... dan {previewData.length - 5} data lainnya
								</td>
							</tr>
						{/if}
					</tbody>
				</table>
			</div>

			<div class="actions">
				<button class="btn btn-secondary" on:click={() => previewData = []}>Batal</button>
				<button class="btn btn-primary" on:click={processImport}>
					Proses Import {isPenyisihan ? '(Penyisihan)' : '(Umum)'}
				</button>
			</div>
		</div>
	{/if}
</div>

<style>
	.checkbox-label {
		display: flex;
		align-items: center;
		cursor: pointer;
		user-select: none;
		margin-bottom: 0.5rem;
	}

	.checkbox-label input {
		position: absolute;
		opacity: 0;
		cursor: pointer;
		height: 0;
		width: 0;
	}

	.checkbox-custom {
		height: 24px;
		width: 24px;
		background-color: var(--bg-secondary);
		border: 2px solid var(--border);
		border-radius: 6px;
		margin-right: 12px;
		position: relative;
		transition: all 0.2s;
	}

	.checkbox-label input:checked ~ .checkbox-custom {
		background-color: var(--primary);
		border-color: var(--primary);
	}

	.checkbox-custom:after {
		content: "";
		position: absolute;
		display: none;
		left: 8px;
		top: 4px;
		width: 6px;
		height: 12px;
		border: solid white;
		border-width: 0 2px 2px 0;
		transform: rotate(45deg);
	}

	.checkbox-label input:checked ~ .checkbox-custom:after {
		display: block;
	}

	.label-text {
		font-size: 1rem;
		color: var(--text-primary);
	}

	.option-desc {
		font-size: 0.875rem;
		color: var(--text-muted);
		margin-left: 36px;
		margin-bottom: 1.5rem;
	}

	.upload-area {
		border: 2px dashed var(--border);
		border-radius: var(--radius-lg);
		padding: 2rem;
		text-align: center;
		margin-bottom: 1.5rem;
		background: var(--bg-secondary);
	}

	.upload-hint {
		margin-top: 1rem;
		font-size: 0.875rem;
		color: var(--text-muted);
	}

	.table-responsive {
		overflow-x: auto;
		margin: 1rem 0;
	}

	table {
		width: 100%;
		border-collapse: collapse;
		font-size: 0.875rem;
	}

	th, td {
		padding: 0.75rem;
		text-align: left;
		border-bottom: 1px solid var(--border);
	}

	th {
		font-weight: 600;
		color: var(--text-muted);
		background: var(--bg-secondary);
	}

	.badge {
		padding: 0.25rem 0.5rem;
		border-radius: 999px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.badge.income {
		background: rgba(34, 197, 94, 0.1);
		color: var(--success);
	}

	.badge.expense {
		background: rgba(239, 68, 68, 0.1);
		color: var(--danger);
	}

	.actions {
		display: flex;
		gap: 1rem;
		justify-content: flex-end;
		margin-top: 1.5rem;
	}
	
	.progress-bar {
		height: 8px;
		background: var(--bg-secondary);
		border-radius: 4px;
		overflow: hidden;
		margin: 1rem 0;
	}
	
	.progress-fill {
		height: 100%;
		background: var(--primary);
		transition: width 0.3s ease;
	}
</style>
