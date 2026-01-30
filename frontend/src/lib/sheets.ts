// Google Sheets sync utility
// Panggil fungsi ini dari SvelteKit setelah operasi CRUD transaksi

const GOOGLE_SCRIPT_URL = import.meta.env.PUBLIC_GOOGLE_SCRIPT_URL || '';

interface TransactionData {
    id: string;
    transaction_date: string;
    type: string;
    amount: number;
    description?: string;
    is_penyisihan: boolean;
    user_id?: string;
    user_name?: string;
    created_at?: string;
}

export async function syncToGoogleSheets(
    eventType: 'INSERT' | 'UPDATE' | 'DELETE',
    record: TransactionData
) {
    if (!GOOGLE_SCRIPT_URL) {
        console.warn('Google Script URL not configured');
        return;
    }

    try {
        const payload = {
            type: eventType,
            table: 'transactions',
            record: eventType !== 'DELETE' ? record : undefined,
            old_record: eventType === 'DELETE' ? record : undefined
        };

        // Use fetch with no-cors mode for Google Apps Script
        await fetch(GOOGLE_SCRIPT_URL, {
            method: 'POST',
            mode: 'no-cors',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        console.log(`Synced to Google Sheets: ${eventType}`);
    } catch (error) {
        console.error('Failed to sync to Google Sheets:', error);
        // Don't throw - sync failure shouldn't block main operation
    }
}
