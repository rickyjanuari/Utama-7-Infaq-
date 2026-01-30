<script lang="ts">
	import { supabase, type Transaction, type MonthlyReport } from '$lib/supabase';
	import { syncToGoogleSheets } from '$lib/sheets';
	import { isAdmin, canViewPenyisihan } from '$lib/stores/auth';
	import { onMount } from 'svelte';
	import Chart from '$lib/components/Chart.svelte';
	import jsPDF from 'jspdf';
	import autoTable from 'jspdf-autotable';
	import html2canvas from 'html2canvas';
	import ReceiptCard from '$lib/components/ReceiptCard.svelte';

	let transactions: Transaction[] = [];
	let filteredTransactions: Transaction[] = [];
	let monthlyReport: MonthlyReport[] = [];
	let loading = true;
	let error = '';
	let activeTab: 'transactions' | 'monthly' | 'analytics' = 'transactions';
	let currentYear = new Date().getFullYear();
	let initialBalance = 0;
	
	// Filter
	let startDate = '';
	let endDate = '';

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
		error = '';
		try {
			// Get initial balance from profiles
			const { data: profileData } = await supabase
				.from('profiles')
				.select('initial_balance')
				.limit(1);
			
			initialBalance = profileData?.[0]?.initial_balance || 0;

			// Get ONLY non-penyisihan transactions for main report
			const { data: txData, error: txError } = await supabase
				.from('transactions')
				.select(`
					*,
					profiles:user_id (name)
				`)
				.eq('is_penyisihan', false)  // Only main transactions
				.order('transaction_date', { ascending: false })
				.order('created_at', { ascending: false });

			if (txError) throw txError;

			transactions = (txData || []).map(t => ({
				...t,
				user_name: t.profiles?.name || 'Unknown'
			}));
			
			applyFilter(); // Initial filter

			// Calculate monthly report from main transactions only
			const monthlyMap = new Map<string, MonthlyReport>();
			
			for (const tx of transactions) {
				const date = new Date(tx.transaction_date);
				if (date.getFullYear() !== currentYear) continue;
				
				const month = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
				
				if (!monthlyMap.has(month)) {
					monthlyMap.set(month, {
						month,
						total_infaq: 0,
						total_pengeluaran: 0,
						saldo: 0
					});
				}

				const report = monthlyMap.get(month)!;
				if (tx.type === 'infaq_masuk') {
					report.total_infaq += Number(tx.amount);
				} else {
					report.total_pengeluaran += Number(tx.amount);
				}
				report.saldo = report.total_infaq - report.total_pengeluaran;
			}

			monthlyReport = Array.from(monthlyMap.values()).sort((a, b) => b.month.localeCompare(a.month));
		} catch (e: unknown) {
			const err = e as { message?: string };
			error = err.message || 'Failed to load data';
		} finally {
			loading = false;
		}
	}

	function applyFilter() {
		if (!startDate && !endDate) {
			filteredTransactions = [...transactions];
			return;
		}

		filteredTransactions = transactions.filter(tx => {
			const date = tx.transaction_date;
			if (startDate && date < startDate) return false;
			if (endDate && date > endDate) return false;
			return true;
		});
	}

	$: {
		// Reactively apply filter when dates change
		if (startDate || endDate || transactions) {
			applyFilter();
		}
	}

	// Chart Data
	$: chartData = {
		labels: monthlyReport.map(m => formatMonth(m.month)).reverse(),
		datasets: [
			{
				label: 'Pemasukan',
				data: monthlyReport.map(m => m.total_infaq).reverse(),
				backgroundColor: '#00C853',
				borderRadius: 4
			},
			{
				label: 'Pengeluaran',
				data: monthlyReport.map(m => m.total_pengeluaran).reverse(),
				backgroundColor: '#FF5252',
				borderRadius: 4
			}
		]
	};

	// Receipt Modal State
	let showReceiptModal = false;
	let receiptTx: Transaction | null = null;

	function openReceiptModal(tx: Transaction) {
		receiptTx = tx;
		showReceiptModal = true;
	}

	function closeReceiptModal() {
		showReceiptModal = false;
		receiptTx = null;
	}

	async function captureReceipt(): Promise<Blob | null> {
		const element = document.getElementById('history-receipt-card');
		if (!element) return null;
		
		try {
			const canvas = await html2canvas(element, {
				scale: 2,
				backgroundColor: '#ffffff',
				useCORS: true
			});
			
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
		a.download = `kwitansi-${receiptTx?.id.substring(0,6) || 'infaq'}.png`;
		a.click();
		URL.revokeObjectURL(url);
	}

	async function shareReceipt() {
		const blob = await captureReceipt();
		if (!blob) return;

		const file = new File([blob], `kwitansi-${receiptTx?.id.substring(0,6) || 'infaq'}.png`, { type: 'image/png' });

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

	// Send WhatsApp Receipt
	function sendWhatsApp(tx: Transaction) {
		const text = `*Kuitansi Digital - INFAQ UTUH*%0A%0A` +
			`Tanggal : ${formatDate(tx.transaction_date)} (%23${tx.id.substring(0, 4)})%0A` +
			`Tipe : ${tx.type === 'infaq_masuk' ? 'Infaq Masuk' : 'Pengeluaran'}%0A` +
			`Jumlah : Rp ${formatNumber(Number(tx.amount))}%0A` +
			`Kategori : ${tx.category || 'Umum'}%0A` +
			`Keterangan : ${tx.description || '-'}%0A%0A` +
			`Terima kasih telah berpartisipasi. Semoga berkah.`;
			
		window.open(`https://wa.me/?text=${text}`, '_blank');
	}

	// PDF Export
	function exportPDF() {
		const doc = new jsPDF();
		
		// Header
		doc.setFontSize(18);
		doc.text('Laporan Keuangan Infaq', 14, 20);
		doc.setFontSize(10);
		doc.text(`Dicetak pada: ${new Date().toLocaleString('id-ID')}`, 14, 28);
		
		if (startDate || endDate) {
			const startStr = startDate ? formatDate(startDate) : 'Awal';
			const endStr = endDate ? formatDate(endDate) : 'Akhir';
			doc.text(`Periode: ${startStr} - ${endStr}`, 14, 34);
		}

		// Summary
		const totalIn = filteredTransactions.filter(t => t.type === 'infaq_masuk').reduce((sum, t) => sum + Number(t.amount), 0);
		const totalOut = filteredTransactions.filter(t => t.type === 'pengeluaran').reduce((sum, t) => sum + Number(t.amount), 0);
		
		doc.text(`Total Pemasukan: ${formatCurrency(totalIn)}`, 14, 45);
		doc.text(`Total Pengeluaran: ${formatCurrency(totalOut)}`, 14, 50);
		doc.text(`Saldo Periode: ${formatCurrency(totalIn - totalOut)}`, 14, 55);

		// Table
		const tableData = filteredTransactions.map(t => [
			formatDate(t.transaction_date),
			t.type === 'infaq_masuk' ? 'Masuk' : 'Keluar',
			t.description || '-',
			t.category || 'Umum',
			formatCurrency(Number(t.amount))
		]);

		autoTable(doc, {
			startY: 65,
			head: [['Tanggal', 'Tipe', 'Keterangan', 'Kategori', 'Jumlah']],
			body: tableData,
			headStyles: { fillColor: [0, 200, 83] }, // Primary color
			theme: 'grid',
			styles: { fontSize: 8 },
			columnStyles: {
				4: { halign: 'right' }
			}
		});

		doc.save(`Laporan_Infaq_${new Date().toISOString().split('T')[0]}.pdf`);
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
			);

			closeEditModal();
		} catch (e: unknown) {
			const err = e as { message?: string };
			editError = err.message || 'Gagal mengupdate transaksi';
		} finally {
			editLoading = false;
		}
	}

	async function handleDelete(tx: Transaction) {
		if (!confirm('Yakin hapus transaksi ini?')) return;
		
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

	function formatMonth(monthStr: string) {
		const [year, month] = monthStr.split('-');
		const date = new Date(parseInt(year), parseInt(month) - 1);
		return date.toLocaleDateString('id-ID', { month: 'long', year: 'numeric' });
	}

	// Calculate totals
	$: totalMasuk = transactions.filter(t => t.type === 'infaq_masuk').reduce((sum, t) => sum + Number(t.amount), 0);
	$: totalKeluar = transactions.filter(t => t.type === 'pengeluaran').reduce((sum, t) => sum + Number(t.amount), 0);
	$: totalSaldo = initialBalance + totalMasuk - totalKeluar;
</script>

<div class="page-header">
	<h1 class="page-title">Laporan Umum</h1>
</div>

<!-- Summary Cards -->
<div class="summary-cards">
	<div class="summary-card balance">
		<p class="summary-label">Total Saldo</p>
		<p class="summary-value">{formatCurrency(totalSaldo)}</p>
		{#if initialBalance > 0}
			<p class="summary-note">Termasuk saldo awal {formatCurrency(initialBalance)}</p>
		{/if}
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

	<div class="tabs">
	<button class="tab" class:active={activeTab === 'transactions'} on:click={() => activeTab = 'transactions'}>
		Riwayat
	</button>
	<button class="tab" class:active={activeTab === 'monthly'} on:click={() => activeTab = 'monthly'}>
		Laporan Bulanan
	</button>
	<button class="tab" class:active={activeTab === 'analytics'} on:click={() => activeTab = 'analytics'}>
		Grafik & Analitik
	</button>
</div>

<!-- Filters -->
<div class="filters card">
	<div class="filter-group">
		<label class="filter-label">Tanggal Awal</label>
		<input type="date" class="form-input" bind:value={startDate} />
	</div>
	<div class="filter-group">
		<label class="filter-label">Tanggal Akhir</label>
		<input type="date" class="form-input" bind:value={endDate} />
	</div>
	<div class="filter-actions">
		<button class="btn btn-primary" on:click={exportPDF} style="padding: 0.5rem 1rem; font-size: 0.875rem;">
			<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="margin-right: 0.5rem;">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
			</svg>
			Export PDF
		</button>
	</div>
</div>

{#if loading}
	<div class="loader">
		<div class="spinner"></div>
	</div>
{:else if error}
	<div class="card" style="text-align: center; color: var(--danger);">
		<p>{error}</p>
		<button class="btn btn-primary" style="margin-top: 1rem;" on:click={loadData}>Coba Lagi</button>
	</div>
{:else if activeTab === 'transactions'}
	{#if filteredTransactions.length === 0}
		<div class="empty-state">
			<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
			</svg>
			<p>Belum ada transaksi</p>
		</div>
	{:else}
		<div class="transaction-list">
			{#each filteredTransactions as tx}
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
								<button class="btn-action share" on:click={() => openReceiptModal(tx)} title="Lihat & Share Kwitansi">
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor">
										<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
									</svg>
								</button>
								<button class="btn-action share" on:click={() => sendWhatsApp(tx)} title="Kirim WA">
									<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 20 20" fill="currentColor">
										<path d="M10.002,0C4.484,0 0,4.48535 0,10C0,12.18666 0.705,14.21526 1.904,15.86076L0.658,19.57687L4.501,18.3485C6.082,19.39482 7.969,20 10.002,20C15.515,20 20,15.51465 20,10C20,4.48535 15.515,0 10.002,0M15.821,14.12124C15.58,14.80344 14.622,15.36761 13.858,15.53266C13.335,15.64369 12.653,15.73172 10.355,14.77943C7.774,13.71011 4.19,9.90097 4.19,7.36621C4.19,6.07582 4.934,4.57337 6.235,4.57337C6.861,4.57337 6.999,4.58538 7.205,5.07952C7.446,5.6617 8.034,7.09613 8.104,7.24317C8.393,7.84635 7.81,8.19946 7.387,8.72462C7.252,8.88266 7.099,9.05372 7.27,9.3478C7.44,9.63589 8.028,10.59418 8.892,11.36341C10.008,12.35771 10.913,12.6748 11.237,12.80984C11.478,12.90987 11.766,12.88687 11.942,12.69881C12.165,12.45774 12.442,12.05762 12.724,11.6635C12.923,11.38141 13.176,11.3464 13.441,11.44643C13.62,11.50845 15.895,12.56477 15.991,12.73382C16.062,12.85686 16.062,13.43903 15.821,14.12124"/>
									</svg>
								</button>
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
{:else if activeTab === 'monthly'}
	<div class="year-selector">
		<button on:click={() => { currentYear--; loadData(); }}>←</button>
		<span>{currentYear}</span>
		<button on:click={() => { currentYear++; loadData(); }} disabled={currentYear >= new Date().getFullYear()}>→</button>
	</div>

	{#if monthlyReport.length === 0}
		<div class="empty-state">
			<p>Belum ada data di tahun {currentYear}</p>
		</div>
	{:else}
		<div class="monthly-list">
			{#each monthlyReport as report}
				<div class="card monthly-card">
					<div class="monthly-header">
						<h3>{formatMonth(report.month)}</h3>
						<span class="badge" class:badge-success={report.saldo >= 0} class:badge-warning={report.saldo < 0}>
							{formatCurrency(report.saldo)}
						</span>
					</div>
					<div class="monthly-stats">
						<div>
							<span class="stat-label">Masuk</span>
							<span class="stat-value income">{formatCurrency(report.total_infaq)}</span>
						</div>
						<div>
							<span class="stat-label">Keluar</span>
							<span class="stat-value expense">{formatCurrency(report.total_pengeluaran)}</span>
						</div>
					</div>
				</div>
			{/each}
		</div>
	{/if}
{:else if activeTab === 'analytics'}
	<div class="card">
		<h3 class="section-title">Tren Bulanan ({currentYear})</h3>
		<Chart type="bar" data={chartData} options={{ scales: { y: { beginAtZero: true } } }} />
	</div>
	
	<div class="card" style="margin-top: 1rem;">
		<h3 class="section-title">Komposisi Pemasukan vs Pengeluaran</h3>
		<div style="height: 300px; display: flex; justify-content: center;">
			<Chart 
				type="doughnut" 
				data={{
					labels: ['Pemasukan', 'Pengeluaran'],
					datasets: [{
						data: [
							monthlyReport.reduce((sum, m) => sum + m.total_infaq, 0),
							monthlyReport.reduce((sum, m) => sum + m.total_pengeluaran, 0)
						],
						backgroundColor: ['#00C853', '#FF5252']
					}]
				}} 
				options={{ maintainAspectRatio: false }}
			/>
		</div>
	</div>
{/if}



<!-- Receipt Modal -->
{#if showReceiptModal && receiptTx}
	<div class="modal-overlay" on:click={closeReceiptModal} on:keydown={(e) => e.key === 'Escape' && closeReceiptModal()}>
		<div class="modal" on:click|stopPropagation>
			<div style="margin-bottom: 1.5rem;" id="history-receipt-card">
				<ReceiptCard transaction={receiptTx} recorderName={receiptTx.user_name || ''} />
			</div>
			
			<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-bottom: 1rem;">
				<button class="btn btn-secondary" on:click={downloadReceipt}>
					<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="margin-right: 0.5rem;">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
					</svg>
					Simpan
				</button>
				<button class="btn btn-primary" on:click={shareReceipt}>
					<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" style="margin-right: 0.5rem;">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
					</svg>
					Share
				</button>
			</div>
			
			<button class="btn btn-secondary btn-block" on:click={closeReceiptModal}>
				Tutup
			</button>
		</div>
	</div>
{/if}

<!-- Edit Modal -->
{#if showEditModal && editingTx}
	<div class="modal-overlay" on:click={closeEditModal} on:keydown={(e) => e.key === 'Escape' && closeEditModal()}>
		<div class="modal" on:click|stopPropagation>
			<h2 class="modal-title">Edit Transaksi</h2>
			
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
							Keluar
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

	.tabs {
		display: flex;
		gap: 0.5rem;
		margin-bottom: 1rem;
	}

	.tab {
		flex: 1;
		padding: 0.625rem;
		border: 2px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--bg-card);
		color: var(--text-secondary);
		font-size: 0.875rem;
		font-weight: 600;
		cursor: pointer;
		transition: all var(--transition-normal);
	}

	.tab.active {
		border-color: var(--primary);
		background: var(--primary-light);
		color: var(--primary);
	}

	.year-selector {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 1.5rem;
		margin-bottom: 1rem;
	}

	.year-selector button {
		width: 36px;
		height: 36px;
		border: 2px solid var(--border);
		border-radius: var(--radius-md);
		background: var(--bg-card);
		color: var(--text-primary);
		font-size: 1rem;
		cursor: pointer;
	}

	.year-selector button:disabled {
		opacity: 0.3;
		cursor: not-allowed;
	}

	.year-selector span {
		font-size: 1.125rem;
		font-weight: 700;
	}

	.monthly-list {
		display: flex;
		flex-direction: column;
		gap: 0.75rem;
	}

	.monthly-card {
		padding: 1rem;
	}

	.monthly-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 0.75rem;
	}

	.monthly-header h3 {
		font-size: 0.9375rem;
		font-weight: 600;
	}

	.monthly-stats {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 1rem;
	}

	.monthly-stats .stat-label {
		display: block;
		font-size: 0.6875rem;
		color: var(--text-muted);
		text-transform: uppercase;
		letter-spacing: 0.03em;
		margin-bottom: 0.125rem;
	}

	.monthly-stats .stat-value {
		font-size: 0.9375rem;
		font-weight: 600;
	}

	/* Filters */
	.filters {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.75rem;
		margin-bottom: 1rem;
		align-items: end;
	}

	.filter-group {
		width: 100%;
	}

	.filter-label {
		display: block;
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--text-secondary);
		margin-bottom: 0.375rem;
	}

	.filter-actions {
		grid-column: 1 / -1;
		display: flex;
		justify-content: flex-end;
	}

	@media (min-width: 480px) {
		.filters {
			grid-template-columns: 1fr 1fr auto;
		}
		
		.filter-actions {
			grid-column: auto;
		}
	}

	.category-badge {
		display: inline-block;
		font-size: 0.625rem;
		font-weight: 600;
		text-transform: uppercase;
		background: var(--primary-light);
		color: var(--primary);
		padding: 0.125rem 0.375rem;
		border-radius: var(--radius-sm);
		margin-left: 0.375rem;
		vertical-align: middle;
	}
</style>
