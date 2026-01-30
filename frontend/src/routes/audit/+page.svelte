<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { isAdmin } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	interface AuditLog {
		id: string;
		user_name: string;
		action: string;
		table_name: string;
		record_id: string;
		old_data: Record<string, unknown>;
		new_data: Record<string, unknown>;
		created_at: string;
	}

	let logs: AuditLog[] = [];
	let loading = true;
	let error = '';

	onMount(async () => {
		if (!$isAdmin) {
			goto('/');
			return;
		}

		try {
			const { data, error: fetchError } = await supabase
				.from('audit_logs')
				.select('*')
				.order('created_at', { ascending: false })
				.limit(50);

			if (fetchError) throw fetchError;
			logs = data || [];
		} catch (e: unknown) {
			const err = e as { message?: string };
			error = err.message || 'Gagal memuat audit log';
		} finally {
			loading = false;
		}
	});

	function formatDate(dateStr: string) {
		return new Date(dateStr).toLocaleString('id-ID', {
			day: 'numeric',
			month: 'short',
			year: 'numeric',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function formatCurrency(amount: unknown): string {
		const num = Number(amount);
		if (isNaN(num)) return String(amount);
		return new Intl.NumberFormat('id-ID', {
			style: 'currency',
			currency: 'IDR',
			minimumFractionDigits: 0
		}).format(num);
	}

	function getActionColor(action: string): string {
		switch (action) {
			case 'INSERT': return 'var(--income)';
			case 'UPDATE': return 'var(--warning)';
			case 'DELETE': return 'var(--danger)';
			default: return 'var(--text-muted)';
		}
	}

	function getActionLabel(action: string): string {
		switch (action) {
			case 'INSERT': return 'Tambah';
			case 'UPDATE': return 'Edit';
			case 'DELETE': return 'Hapus';
			default: return action;
		}
	}
</script>

<div class="page-header">
	<h1 class="page-title">Audit Log</h1>
	<a href="/settings" class="back-link">← Kembali</a>
</div>

{#if loading}
	<div class="loader">
		<div class="spinner"></div>
	</div>
{:else if error}
	<div class="message error">{error}</div>
{:else if logs.length === 0}
	<div class="empty-state">
		<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
		</svg>
		<p>Belum ada aktivitas tercatat</p>
		<small>Jalankan SQL di Supabase untuk mengaktifkan audit log</small>
	</div>
{:else}
	<div class="audit-list">
		{#each logs as log}
			<div class="audit-item">
				<div class="audit-header">
					<span class="audit-action" style="color: {getActionColor(log.action)}">
						{getActionLabel(log.action)}
					</span>
					<span class="audit-date">{formatDate(log.created_at)}</span>
				</div>
				<div class="audit-details">
					<span class="audit-user">{log.user_name || 'System'}</span>
					{#if log.action === 'INSERT' && log.new_data}
						<span class="audit-amount income">
							+{formatCurrency(log.new_data.amount)}
						</span>
					{:else if log.action === 'DELETE' && log.old_data}
						<span class="audit-amount expense">
							-{formatCurrency(log.old_data.amount)}
						</span>
					{:else if log.action === 'UPDATE' && log.new_data}
						<span class="audit-amount">
							{formatCurrency(log.new_data.amount)}
						</span>
					{/if}
				</div>
				{#if log.new_data?.description || log.old_data?.description}
					<div class="audit-desc">
						{log.new_data?.description || log.old_data?.description}
					</div>
				{/if}
			</div>
		{/each}
	</div>
{/if}

<style>
	.back-link {
		font-size: 0.875rem;
		color: var(--primary);
		text-decoration: none;
	}

	.audit-list {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}

	.audit-item {
		background: var(--bg-card);
		border-radius: var(--radius-lg);
		padding: 1rem;
		box-shadow: var(--shadow-xs);
	}

	.audit-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.5rem;
	}

	.audit-action {
		font-size: 0.75rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.03em;
	}

	.audit-date {
		font-size: 0.75rem;
		color: var(--text-muted);
	}

	.audit-details {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.audit-user {
		font-weight: 600;
		font-size: 0.9375rem;
	}

	.audit-amount {
		font-weight: 700;
		font-size: 0.9375rem;
	}

	.audit-amount.income {
		color: var(--income);
	}

	.audit-amount.expense {
		color: var(--expense);
	}

	.audit-desc {
		font-size: 0.8125rem;
		color: var(--text-muted);
		margin-top: 0.25rem;
	}

	.empty-state small {
		display: block;
		margin-top: 0.5rem;
		color: var(--text-light);
	}
</style>
