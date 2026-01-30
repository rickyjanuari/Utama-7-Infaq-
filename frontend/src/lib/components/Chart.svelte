<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import Chart from 'chart.js/auto';
	import type { ChartConfiguration } from 'chart.js';

	export let type: ChartConfiguration['type'] = 'bar';
	export let data: ChartConfiguration['data'];
	export let options: ChartConfiguration['options'] = {};
	export let height: string = '300px';

	let canvas: HTMLCanvasElement;
	let chart: Chart;

	// Helper to handle responsive resizing
	$: if (chart && data) {
		chart.data = data;
		chart.update();
	}

	onMount(() => {
		if (canvas) {
			chart = new Chart(canvas, {
				type,
				data,
				options: {
					responsive: true,
					maintainAspectRatio: false,
					...options
				}
			});
		}
	});

	onDestroy(() => {
		if (chart) {
			chart.destroy();
		}
	});
</script>

<div class="chart-container" style="height: {height}; position: relative;">
	<canvas bind:this={canvas}></canvas>
</div>

<style>
	.chart-container {
		width: 100%;
	}
</style>
