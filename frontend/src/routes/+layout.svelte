<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import { auth, isAuthenticated, canCreateTransaction, canViewPenyisihan, isAdmin } from '$lib/stores/auth';
	import { theme } from '$lib/stores/theme';
	import { goto } from '$app/navigation';
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';

	onMount(async () => {
		await auth.init();
	});

	// Public routes that don't require authentication
	const publicRoutes = ['/login', '/public'];
	$: isPublicRoute = publicRoutes.some(route => $page.url.pathname.startsWith(route));

	// Redirect to login if not authenticated (except public routes)
	$: if (browser && $auth.initialized && !$isAuthenticated && !isPublicRoute) {
		goto('/login');
	}

	const navItems = [
		{ href: '/', label: 'Beranda', icon: 'home' },
		{ href: '/infaq', label: 'Input', icon: 'plus', requireCreate: true },
		{ href: '/laporan', label: 'Laporan', icon: 'chart' },
		{ href: '/penyisihan', label: 'Privat', icon: 'lock', requirePenyisihan: true }
	];

	async function handleLogout() {
		await auth.logout();
		goto('/login');
	}
</script>

<svelte:head>
	<title>Infaq App</title>
</svelte:head>

{#if $auth.loading}
	<div class="loader" style="height: 100vh; align-items: center;">
		<div class="spinner"></div>
	</div>
{:else if $isAuthenticated && $page.url.pathname !== '/login'}
	<!-- Theme Toggle Button -->
	<button class="theme-toggle" on:click={() => theme.toggle()} aria-label="Toggle theme">
		{#if $theme === 'light'}
			<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
			</svg>
		{:else}
			<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
			</svg>
		{/if}
	</button>

	<main class="main-content">
		<div class="container">
			<slot />
		</div>
	</main>

	<nav class="bottom-nav">
		<div class="sidebar-header">
			<div class="sidebar-logo-img">
				<img src="/logo.png" alt="Logo" />
			</div>
			<div class="sidebar-title">
				<h3>INFAQ UTUH</h3>
				<p>Management System</p>
			</div>
		</div>
		<ul>
			{#each navItems as item}
				{#if (!item.requireCreate || $canCreateTransaction) && (!item.requirePenyisihan || $canViewPenyisihan)}
					<li>
						<a href={item.href} class:active={$page.url.pathname === item.href}>
							{#if item.icon === 'home'}
								<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
								</svg>
							{:else if item.icon === 'plus'}
								<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
								</svg>
							{:else if item.icon === 'chart'}
								<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
								</svg>
							{:else if item.icon === 'lock'}
								<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
								</svg>
							{/if}
							<span>{item.label}</span>
						</a>
					</li>
				{/if}
			{/each}
			{#if $isAdmin}
				<li>
					<a href="/settings" class:active={$page.url.pathname === '/settings'}>
						<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
						</svg>
						<span>Settings</span>
					</a>
				</li>
			{/if}
		</ul>
	</nav>
{:else}
	<slot />
{/if}

<style>
	.theme-toggle {
		position: fixed;
		top: 1rem;
		right: 1rem;
		width: 40px;
		height: 40px;
		border-radius: 50%;
		border: none;
		background: var(--bg-card);
		color: var(--text-primary);
		box-shadow: var(--shadow-md);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 99;
		transition: all var(--transition-normal);
	}

	.theme-toggle:hover {
		transform: scale(1.05);
		box-shadow: var(--shadow-lg);
	}
</style>
