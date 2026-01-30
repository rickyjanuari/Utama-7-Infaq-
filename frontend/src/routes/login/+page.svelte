<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { auth } from '$lib/stores/auth';
	import { goto } from '$app/navigation';

	let email = '';
	let password = '';
	let loading = false;
	let error = '';

	async function handleLogin() {
		if (!email || !password) {
			error = 'Email dan password harus diisi';
			return;
		}

		loading = true;
		error = '';

		try {
			const { error: signInError } = await supabase.auth.signInWithPassword({
				email,
				password
			});

			if (signInError) throw signInError;

			await auth.init();
			goto('/');
		} catch (e: unknown) {
			const err = e as { message?: string };
			if (err.message?.includes('Invalid login')) {
				error = 'Email atau password salah';
			} else {
				error = err.message || 'Gagal login';
			}
		} finally {
			loading = false;
		}
	}
</script>

<div class="login-page">
	<div class="login-header">
		<div class="app-logo">
			<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
				<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1.41 16.09V20h-2.67v-1.93c-1.71-.36-3.16-1.46-3.27-3.4h1.96c.1 1.05.82 1.87 2.65 1.87 1.96 0 2.4-.98 2.4-1.59 0-.83-.44-1.61-2.67-2.14-2.48-.6-4.18-1.62-4.18-3.67 0-1.72 1.39-2.84 3.11-3.21V4h2.67v1.95c1.86.45 2.79 1.86 2.85 3.39H14.3c-.05-1.11-.64-1.87-2.22-1.87-1.5 0-2.4.68-2.4 1.64 0 .84.65 1.39 2.67 1.91s4.18 1.39 4.18 3.91c-.01 1.83-1.38 2.83-3.12 3.16z"/>
			</svg>
		</div>
		<h1 class="app-name">Infaq App</h1>
		<p class="app-tagline">Kelola Dana Infaq dengan Mudah</p>
	</div>

	<div class="login-card">
		{#if error}
			<div class="message error">
				{error}
			</div>
		{/if}

		<form on:submit|preventDefault={handleLogin}>
			<div class="form-group">
				<label for="email" class="form-label">Email</label>
				<input
					type="email"
					id="email"
					class="form-input"
					placeholder="nama@email.com"
					bind:value={email}
					disabled={loading}
					autocomplete="email"
				/>
			</div>

			<div class="form-group">
				<label for="password" class="form-label">Password</label>
				<input
					type="password"
					id="password"
					class="form-input"
					placeholder="••••••••"
					bind:value={password}
					disabled={loading}
					autocomplete="current-password"
				/>
			</div>

			<button type="submit" class="btn btn-primary btn-block" disabled={loading}>
				{#if loading}
					<div class="spinner" style="width: 20px; height: 20px; border-width: 2px;"></div>
				{:else}
					Masuk
				{/if}
			</button>
		</form>
	</div>

	<p class="footer-text">v2.0 • 2026</p>
</div>

<style>
	.login-page {
		min-height: 100vh;
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 2rem 1.5rem;
		background: linear-gradient(180deg, #F5F7FA 0%, #E8F5E9 100%);
	}

	.login-header {
		text-align: center;
		margin-bottom: 2rem;
	}

	.app-logo {
		width: 64px;
		height: 64px;
		margin: 0 auto 1rem;
		background: var(--primary-gradient);
		border-radius: var(--radius-xl);
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 8px 24px rgba(0, 200, 83, 0.3);
	}

	.app-logo svg {
		width: 32px;
		height: 32px;
		color: white;
	}

	.app-name {
		font-size: 1.75rem;
		font-weight: 800;
		color: var(--text-primary);
		margin-bottom: 0.375rem;
	}

	.app-tagline {
		font-size: 0.9375rem;
		color: var(--text-muted);
	}

	.login-card {
		width: 100%;
		max-width: 360px;
		background: var(--bg-card);
		border-radius: var(--radius-2xl);
		padding: 1.75rem;
		box-shadow: var(--shadow-lg);
	}

	.footer-text {
		margin-top: 2rem;
		font-size: 0.75rem;
		color: var(--text-light);
	}
</style>
