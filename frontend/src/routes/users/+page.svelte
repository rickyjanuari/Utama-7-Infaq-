<script lang="ts">
	import { supabase, type Profile } from '$lib/supabase';
	import { onMount } from 'svelte';

	let users: Profile[] = [];
	let loading = true;
	let error = '';
	let showForm = false;
	let editingUser: Profile | null = null;

	// Form fields
	let email = '';
	let password = '';
	let name = '';
	let role: 'admin' | 'guru' | 'kepala_sekolah' = 'guru';
	let canViewPenyisihan = false;
	let formLoading = false;
	let formError = '';

	onMount(async () => {
		await loadUsers();
	});

	async function loadUsers() {
		loading = true;
		error = '';
		try {
			const { data, error: fetchError } = await supabase
				.from('profiles')
				.select('*')
				.order('created_at', { ascending: false });

			if (fetchError) throw fetchError;
			users = data || [];
		} catch (e: unknown) {
			const err = e as { message?: string };
			error = err.message || 'Failed to load users';
		} finally {
			loading = false;
		}
	}

	function openCreateForm() {
		editingUser = null;
		email = '';
		password = '';
		name = '';
		role = 'guru';
		canViewPenyisihan = false;
		formError = '';
		showForm = true;
	}

	function openEditForm(user: Profile) {
		editingUser = user;
		email = user.email;
		password = '';
		name = user.name;
		role = user.role;
		canViewPenyisihan = user.can_view_penyisihan;
		formError = '';
		showForm = true;
	}

	function closeForm() {
		showForm = false;
		editingUser = null;
	}

	async function handleSubmit() {
		if (!email || !name) {
			formError = 'Email dan nama harus diisi';
			return;
		}

		if (!editingUser && !password) {
			formError = 'Password harus diisi';
			return;
		}

		formLoading = true;
		formError = '';

		try {
			if (editingUser) {
				// Update existing user profile
				const { error: updateError } = await supabase
					.from('profiles')
					.update({
						email,
						name,
						role,
						can_view_penyisihan: canViewPenyisihan,
						updated_at: new Date().toISOString()
					})
					.eq('id', editingUser.id);

				if (updateError) throw updateError;
			} else {
				// Create new user via Supabase Admin API
				// Note: This requires service role key, so we do it via edge function or manually
				const { data: authData, error: signUpError } = await supabase.auth.signUp({
					email,
					password,
					options: {
						data: {
							name,
							role,
							can_view_penyisihan: canViewPenyisihan
						}
					}
				});

				if (signUpError) throw signUpError;

				// If user already exists in auth, just update profile
				if (authData.user && !authData.session) {
					formError = 'User dengan email ini sudah terdaftar';
					formLoading = false;
					return;
				}
			}
			
			closeForm();
			await loadUsers();
		} catch (e: unknown) {
			const err = e as { message?: string };
			formError = err.message || 'Gagal menyimpan user';
		} finally {
			formLoading = false;
		}
	}

	async function handleDelete(user: Profile) {
		if (!confirm(`Yakin hapus user "${user.name}"?`)) return;
		
		try {
			// Note: Deleting from profiles will cascade due to RLS
			// But to fully delete, we need admin access to delete from auth.users
			const { error: delError } = await supabase
				.from('profiles')
				.delete()
				.eq('id', user.id);

			if (delError) throw delError;
			users = users.filter(u => u.id !== user.id);
		} catch (e: unknown) {
			const err = e as { message?: string };
			alert('Gagal menghapus: ' + (err.message || 'Unknown error'));
		}
	}

	function getRoleName(r: string) {
		switch (r) {
			case 'admin': return 'Admin';
			case 'guru': return 'Guru';
			case 'kepala_sekolah': return 'Kepala Sekolah';
			default: return r;
		}
	}
</script>

<div class="page-header">
	<h1 class="page-title">Kelola User</h1>
	<button class="btn btn-primary" on:click={openCreateForm}>
		<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
		</svg>
		Tambah
	</button>
</div>

{#if loading}
	<div class="loader">
		<div class="spinner"></div>
	</div>
{:else if error}
	<div class="card" style="text-align: center; color: var(--danger);">
		<p>{error}</p>
		<button class="btn btn-primary" style="margin-top: 1rem;" on:click={loadUsers}>Coba Lagi</button>
	</div>
{:else if users.length === 0}
	<div class="empty-state">
		<p>Belum ada user</p>
	</div>
{:else}
	<div class="user-list">
		{#each users as user}
			<div class="user-card">
				<div class="user-info">
					<div class="user-avatar">
						{user.name.charAt(0).toUpperCase()}
					</div>
					<div>
						<div class="user-name">{user.name}</div>
						<div class="user-email">{user.email}</div>
						<div class="user-badges">
							<span class="badge" class:badge-success={user.role === 'admin'} class:badge-warning={user.role === 'kepala_sekolah'}>
								{getRoleName(user.role)}
							</span>
							{#if user.can_view_penyisihan}
								<span class="badge badge-private">Penyisihan</span>
							{/if}
						</div>
					</div>
				</div>
				<div class="user-actions">
					<button class="action-btn" on:click={() => openEditForm(user)} title="Edit">
						<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
						</svg>
						Edit
					</button>
					<button class="action-btn danger" on:click={() => handleDelete(user)} title="Hapus">
						<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
						</svg>
						Hapus
					</button>
				</div>
			</div>
		{/each}
	</div>
{/if}

{#if showForm}
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="modal-overlay" on:click={closeForm} on:keydown={(e) => e.key === 'Escape' && closeForm()} role="button" tabindex="0">
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="modal" on:click|stopPropagation role="dialog" aria-modal="true">
			<h2 class="modal-title">{editingUser ? 'Edit User' : 'Tambah User'}</h2>
			
			<form on:submit|preventDefault={handleSubmit}>
				{#if formError}
					<div class="message error">{formError}</div>
				{/if}

				<div class="form-group">
					<label for="name" class="form-label">Nama</label>
					<input type="text" id="name" class="form-input" bind:value={name} disabled={formLoading} />
				</div>

				<div class="form-group">
					<label for="email" class="form-label">Email</label>
					<input type="email" id="email" class="form-input" bind:value={email} disabled={formLoading || !!editingUser} />
				</div>

				{#if !editingUser}
					<div class="form-group">
						<label for="password" class="form-label">Password</label>
						<input type="password" id="password" class="form-input" bind:value={password} disabled={formLoading} />
					</div>
				{/if}

				<div class="form-group">
					<label for="role" class="form-label">Role</label>
					<select id="role" class="form-input" bind:value={role} disabled={formLoading}>
						<option value="admin">Admin</option>
						<option value="guru">Guru</option>
						<option value="kepala_sekolah">Kepala Sekolah</option>
					</select>
				</div>

				<div class="form-group">
					<label class="toggle">
						<input type="checkbox" bind:checked={canViewPenyisihan} disabled={formLoading} />
						<span class="toggle-switch"></span>
						<span>Akses Penyisihan</span>
					</label>
				</div>

				<div style="display: flex; gap: 0.75rem; margin-top: 1.5rem;">
					<button type="button" class="btn btn-secondary" style="flex: 1;" on:click={closeForm} disabled={formLoading}>
						Batal
					</button>
					<button type="submit" class="btn btn-primary" style="flex: 1;" disabled={formLoading}>
						{#if formLoading}
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
	.user-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.user-card {
		background: var(--bg-card);
		border: 1px solid var(--border-light);
		border-radius: var(--radius-lg);
		padding: 1rem;
	}

	.user-info {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 0.75rem;
	}

	.user-avatar {
		width: 48px;
		height: 48px;
		border-radius: 50%;
		background: linear-gradient(135deg, var(--primary), #0d9488);
		color: white;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1.25rem;
		font-weight: 600;
		flex-shrink: 0;
	}

	.user-name {
		font-weight: 600;
		margin-bottom: 0.125rem;
	}

	.user-email {
		font-size: 0.875rem;
		color: var(--text-muted);
		margin-bottom: 0.5rem;
	}

	.user-badges {
		display: flex;
		gap: 0.375rem;
		flex-wrap: wrap;
	}

	.user-actions {
		display: flex;
		gap: 0.5rem;
		border-top: 1px solid var(--border-light);
		padding-top: 0.75rem;
	}

	.action-btn {
		flex: 1;
		padding: 0.5rem;
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		background: transparent;
		color: var(--text-secondary);
		font-size: 0.875rem;
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.action-btn:hover {
		background: var(--bg-tertiary);
		color: var(--text-primary);
	}

	.action-btn.danger {
		border-color: var(--danger);
		color: var(--danger);
	}

	.action-btn.danger:hover {
		background: rgba(239, 68, 68, 0.1);
	}

	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.7);
		display: flex;
		align-items: flex-end;
		justify-content: center;
		z-index: 200;
		padding: 1rem;
	}

	.modal {
		background: var(--bg-secondary);
		border-radius: var(--radius-xl) var(--radius-xl) 0 0;
		padding: 1.5rem;
		width: 100%;
		max-width: 480px;
		max-height: 90vh;
		overflow-y: auto;
	}

	.modal-title {
		font-size: 1.25rem;
		font-weight: 600;
		margin-bottom: 1.5rem;
	}

	.message.error {
		background: rgba(239, 68, 68, 0.1);
		border: 1px solid var(--danger);
		color: var(--danger);
		padding: 0.75rem 1rem;
		border-radius: var(--radius-md);
		margin-bottom: 1rem;
		font-size: 0.875rem;
	}
</style>
