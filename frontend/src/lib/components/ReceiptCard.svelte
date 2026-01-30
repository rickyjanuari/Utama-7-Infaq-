<script lang="ts">
	import type { Transaction } from '$lib/supabase';

	export let transaction: Transaction;
	export let recorderName: string = '';

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
			month: 'long',
			year: 'numeric'
		});
	}
</script>

<div class="receipt" id="receipt-card">
	<div class="receipt-header">
		<img src="/logo.png" alt="Logo" class="receipt-logo" />
		<div class="receipt-title">
			<h3>INFAQ UTUH</h3>
			<p>Kwitansi Resmi</p>
		</div>
	</div>

	<div class="receipt-divider"></div>

	<div class="receipt-body">
		<div class="receipt-row">
			<span class="label">No. Transaksi</span>
			<span class="value">#{transaction.id ? transaction.id.substring(0, 8).toUpperCase() : '-'}</span>
		</div>
		<div class="receipt-row">
			<span class="label">Tanggal</span>
			<span class="value">{formatDate(transaction.transaction_date)}</span>
		</div>
		<div class="receipt-row">
			<span class="label">Pencatat</span>
			<span class="value highlight">{recorderName || transaction.user_name || '-'}</span>
		</div>
		
		<div class="receipt-divider dashed"></div>

		<div class="receipt-row">
			<span class="label">Tipe</span>
			<span class="value type" class:income={transaction.type === 'infaq_masuk'} class:expense={transaction.type === 'pengeluaran'}>
				{transaction.type === 'infaq_masuk' ? 'Infaq Masuk' : 'Pengeluaran'}
			</span>
		</div>
		<div class="receipt-row">
			<span class="label">Kategori</span>
			<span class="value">{transaction.category || 'Umum'}</span>
		</div>
		<div class="receipt-row">
			<span class="label">Keterangan</span>
			<span class="value desc">{transaction.description || '-'}</span>
		</div>

		<div class="receipt-divider dashed"></div>

		<div class="receipt-total">
			<span class="total-label">Total Jumlah</span>
			<span class="total-amount" class:income={transaction.type === 'infaq_masuk'} class:expense={transaction.type === 'pengeluaran'}>
				{formatCurrency(Number(transaction.amount))}
			</span>
		</div>
	</div>

	<div class="receipt-footer">
		<p>Terima kasih atas partisipasi Anda.</p>
		<p class="website">infaq-utuh.app</p>
	</div>
</div>

<style>
	.receipt {
		width: 100%;
		max-width: 320px; /* Mobile friendly receipt width */
		background: #ffffff;
		padding: 1.5rem;
		border-radius: 12px;
		/* Subtle border for printed look */
		box-shadow: 0 4px 24px rgba(0,0,0,0.08); 
		font-family: 'Inter', sans-serif;
		color: #1A1D26;
		position: relative;
		overflow: hidden;
		margin: 0 auto;
	}

	/* Optional: Add a subtle paper texture background pattern if desired */
	.receipt::before {
		content: '';
		position: absolute;
		top: 0; left: 0; right: 0; height: 6px;
		background: linear-gradient(90deg, #00C853, #6366F1);
	}

	.receipt-header {
		display: flex;
		align-items: center;
		gap: 0.75rem;
		margin-bottom: 1.25rem;
	}

	.receipt-logo {
		width: 48px;
		height: 48px;
		object-fit: contain;
	}

	.receipt-title h3 {
		font-size: 1.125rem;
		font-weight: 800;
		color: #00C853;
		margin: 0;
		line-height: 1.2;
	}

	.receipt-title p {
		font-size: 0.75rem;
		color: #99A1B7;
		margin: 0;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.05em;
	}

	.receipt-divider {
		height: 1px;
		background: #E8E9ED;
		margin: 1rem 0;
	}

	.receipt-divider.dashed {
		background: none;
		border-top: 1px dashed #E8E9ED;
	}

	.receipt-row {
		display: flex;
		justify-content: space-between;
		margin-bottom: 0.75rem;
		font-size: 0.8125rem;
	}

	.label {
		color: #99A1B7;
		font-weight: 500;
	}

	.value {
		font-weight: 600;
		text-align: right;
		max-width: 60%;
	}
	
	.value.highlight {
		color: #1A1D26;
		font-weight: 700;
	}

	.value.desc {
		font-style: italic;
		color: #5E6278;
	}

	.value.type.income { color: #00C853; }
	.value.type.expense { color: #FF5252; }

	.receipt-total {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-top: 0.5rem;
	}

	.total-label {
		font-size: 0.9375rem;
		font-weight: 700;
	}

	.total-amount {
		font-size: 1.25rem;
		font-weight: 800;
	}

	.total-amount.income { color: #00C853; }
	.total-amount.expense { color: #FF5252; }

	.receipt-footer {
		margin-top: 1.5rem;
		text-align: center;
		font-size: 0.6875rem;
		color: #99A1B7;
	}

	.website {
		color: #00C853;
		font-weight: 600;
		margin-top: 0.25rem;
	}
</style>
