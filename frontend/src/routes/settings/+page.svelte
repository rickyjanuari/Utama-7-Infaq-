<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { isAdmin } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	let initialBalance = '';
	let initialPenyisihan = '';
	let monthlyTarget = '';
	let loading = true;
	let saving = false;
	let success = '';
	let error = '';

	let qrisPreview = '';
	
	onMount(async () => {
		if (!$isAdmin) {
			goto('/');
			return;
		}

		try {
			const { data } = await supabase
				.from('profiles')
				.select('initial_balance, initial_penyisihan, monthly_target, qris_url')
				.limit(1);

			const profile = data?.[0];
			if (profile) {
				initialBalance = profile.initial_balance ? formatNumber(Number(profile.initial_balance)) : '';
				initialPenyisihan = profile.initial_penyisihan ? formatNumber(Number(profile.initial_penyisihan)) : '';
				monthlyTarget = profile.monthly_target ? formatNumber(Number(profile.monthly_target)) : '';
				qrisPreview = profile.qris_url || '';
			}
		} catch (e) {
			console.error(e);
		} finally {
			loading = false;
		}
	});

	async function handleSave() {
		saving = true;
		error = '';
		success = '';

		const balanceNum = initialBalance ? parseFloat(initialBalance.replace(/[^0-9]/g, '')) : 0;
		const penyisihanNum = initialPenyisihan ? parseFloat(initialPenyisihan.replace(/[^0-9]/g, '')) : 0;
		const targetNum = monthlyTarget ? parseFloat(monthlyTarget.replace(/[^0-9]/g, '')) : 0;

		try {
			const { error: updateError } = await supabase
				.from('profiles')
				.update({
					initial_balance: balanceNum,
					initial_penyisihan: penyisihanNum,
					monthly_target: targetNum,
					qris_url: qrisPreview // Save base64 string directly
				})
				.neq('id', '00000000-0000-0000-0000-000000000000');

			if (updateError) throw updateError;

			success = 'Pengaturan berhasil disimpan!';
		} catch (e: unknown) {
			const err = e as { message?: string };
			error = err.message || 'Gagal menyimpan';
		} finally {
			saving = false;
		}
	}

	function handleFileSelect(e: Event) {
		const target = e.target as HTMLInputElement;
		const file = target.files?.[0];
		
		if (!file) return;

		// Limit to 500KB to avoid DB bloat
		if (file.size > 500 * 1024) {
			error = 'Ukuran file terlalu besar (Maks 500KB)';
			return;
		}

		const reader = new FileReader();
		reader.onload = (e) => {
			qrisPreview = e.target?.result as string;
		};
		reader.readAsDataURL(file);
	}

	function removeQris() {
		if (confirm('Hapus gambar QRIS?')) {
			qrisPreview = '';
		}
	}

	function formatNumber(num: number): string {
		return new Intl.NumberFormat('id-ID').format(num);
	}

	function formatAmount(e: Event, field: 'balance' | 'penyisihan' | 'target') {
		const input = e.target as HTMLInputElement;
		const value = input.value.replace(/[^0-9]/g, '');
		const formatted = value ? new Intl.NumberFormat('id-ID').format(parseInt(value)) : '';
		if (field === 'balance') {
			initialBalance = formatted;
		} else if (field === 'penyisihan') {
			initialPenyisihan = formatted;
		} else {
			monthlyTarget = formatted;
		}
	}
</script>

<div class="page-header">
	<h1 class="page-title">Pengaturan</h1>
</div>

{#if loading}
	<div class="loader">
		<div class="spinner"></div>
	</div>
{:else}
	<!-- Quick Links -->
	<div class="quick-links">
		<a href="/users" class="link-card">
			<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
			</svg>
			<span>Kelola Users</span>
		</a>
		<a href="/audit" class="link-card">
			<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
			</svg>
			<span>Audit Log</span>
		</a>
	</div>

	<div class="card">
		<h2 class="section-title">Saldo Awal</h2>
		<p class="section-desc">Atur saldo awal jika ada data sebelumnya</p>

		{#if success}
			<div class="message success">{success}</div>
		{/if}
		{#if error}
			<div class="message error">{error}</div>
		{/if}

		<form on:submit|preventDefault={handleSave}>
			<div class="form-group">
				<label for="initialBalance" class="form-label">Saldo Awal Dana Umum (Rp)</label>
				<input
					type="text"
					id="initialBalance"
					class="form-input"
					placeholder="0"
					bind:value={initialBalance}
					on:input={(e) => formatAmount(e, 'balance')}
					disabled={saving}
					inputmode="numeric"
				/>
			</div>

			<div class="form-group">
				<label for="initialPenyisihan" class="form-label">Saldo Awal Dana Penyisihan (Rp)</label>
				<input
					type="text"
					id="initialPenyisihan"
					class="form-input"
					placeholder="0"
					bind:value={initialPenyisihan}
					on:input={(e) => formatAmount(e, 'penyisihan')}
					disabled={saving}
					inputmode="numeric"
				/>
			</div>

			<hr class="divider" />

			<h2 class="section-title">Target Bulanan</h2>
			<p class="section-desc">Target infaq bulanan yang ingin dicapai</p>

			<div class="form-group">
				<label for="monthlyTarget" class="form-label">Target Infaq Bulanan (Rp)</label>
				<input
					type="text"
					id="monthlyTarget"
					class="form-input"
					placeholder="0"
					bind:value={monthlyTarget}
					on:input={(e) => formatAmount(e, 'target')}
					disabled={saving}
					inputmode="numeric"
				/>
			</div>

			<hr class="divider" />

			<h2 class="section-title">QRIS Masjid</h2>
			<p class="section-desc">Upload kode QRIS agar tampil di halaman publik</p>

			<div class="form-group">
				{#if qrisPreview}
					<div class="qris-preview-container">
						<img src={qrisPreview} alt="QRIS Preview" class="qris-preview" />
						<button type="button" class="btn-remove-qris" on:click={removeQris} disabled={saving}>Hapus</button>
					</div>
				{/if}
				
				<label class="file-upload-btn">
					<input type="file" accept="image/*" on:change={handleFileSelect} disabled={saving} />
					<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
					</svg>
					{qrisPreview ? 'Ganti Gambar QRIS' : 'Upload Gambar QRIS'}
				</label>
				<small style="color: var(--text-muted); display: block; margin-top: 0.5rem">Maksimal 500KB. Format JPG/PNG.</small>
			</div>

			<button type="submit" class="btn btn-primary btn-block" disabled={saving} style="margin-top: 2rem;">
				{#if saving}
					<div class="spinner" style="width: 20px; height: 20px; border-width: 2px;"></div>
				{:else}
					Simpan Pengaturan
				{/if}
			</button>
		</form>
	</div>
{/if}

<style>
	.quick-links {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1.25rem;
	}

	.link-card {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 1rem;
		background: var(--bg-card);
		border-radius: var(--radius-lg);
		box-shadow: var(--shadow-card);
		text-decoration: none;
		color: var(--text-primary);
		font-weight: 600;
		font-size: 0.875rem;
		transition: all var(--transition-normal);
	}

	.link-card:hover {
		transform: translateY(-2px);
		box-shadow: var(--shadow-md);
	}

	.link-card svg {
		color: var(--primary);
	}

	.section-title {
		font-size: 1rem;
		font-weight: 700;
		margin-bottom: 0.25rem;
	}

	.section-desc {
		font-size: 0.8125rem;
		color: var(--text-muted);
		margin-bottom: 1.25rem;
	}

	.divider {
		border: none;
		border-top: 1px solid var(--border);
		margin: 1.5rem 0;
	}

	.message {
		margin-bottom: 1rem;
	}

	.file-upload-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.5rem;
		padding: 1rem;
		border: 2px dashed var(--border);
		border-radius: var(--radius-md);
		cursor: pointer;
		font-weight: 500;
		color: var(--text-secondary);
		transition: all 0.2s;
	}

	.file-upload-btn:hover {
		border-color: var(--primary);
		color: var(--primary);
		background: var(--bg-tertiary);
	}

	.file-upload-btn input {
		display: none;
	}

	.qris-preview-container {
		margin-bottom: 1rem;
		text-align: center;
		position: relative;
	}

	.qris-preview {
		max-width: 200px;
		border-radius: var(--radius-md);
		border: 1px solid var(--border);
	}

	.btn-remove-qris {
		display: block;
		margin: 0.5rem auto 0;
		background: transparent;
		border: none;
		color: var(--danger);
		font-size: 0.875rem;
		cursor: pointer;
		text-decoration: underline;
	}
</style>
