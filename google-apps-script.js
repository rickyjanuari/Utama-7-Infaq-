// Google Apps Script untuk Sync Infaq App ke Google Sheets
// Paste kode ini di Google Apps Script (script.google.com)

// =====================================================
// KONFIGURASI - Ganti dengan Sheet ID Anda
// =====================================================
const SPREADSHEET_ID = 'GANTI_DENGAN_SPREADSHEET_ID_ANDA';
const SHEET_NAME = 'Transaksi';

// =====================================================
// SETUP AWAL - Jalankan sekali untuk membuat sheet
// =====================================================
function setupSheet() {
    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    let sheet = ss.getSheetByName(SHEET_NAME);

    if (!sheet) {
        sheet = ss.insertSheet(SHEET_NAME);
    }

    // Set header
    const headers = [
        'ID', 'Tanggal', 'Tipe', 'Jumlah', 'Keterangan',
        'Penyisihan', 'User ID', 'User Name', 'Created At'
    ];
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
    sheet.getRange(1, 1, 1, headers.length).setBackground('#10b981');
    sheet.getRange(1, 1, 1, headers.length).setFontColor('white');

    // Format columns
    sheet.setColumnWidth(1, 300); // ID
    sheet.setColumnWidth(2, 120); // Tanggal
    sheet.setColumnWidth(3, 100); // Tipe
    sheet.setColumnWidth(4, 150); // Jumlah
    sheet.setColumnWidth(5, 250); // Keterangan
    sheet.setColumnWidth(6, 80);  // Penyisihan
    sheet.setColumnWidth(7, 300); // User ID
    sheet.setColumnWidth(8, 150); // User Name
    sheet.setColumnWidth(9, 180); // Created At

    Logger.log('Sheet setup completed!');
}

// =====================================================
// WEB APP - Endpoint untuk menerima data dari Supabase
// =====================================================
function doPost(e) {
    try {
        const data = JSON.parse(e.postData.contents);
        const eventType = data.type; // INSERT, UPDATE, DELETE
        const record = data.record || data.old_record;

        const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
        const sheet = ss.getSheetByName(SHEET_NAME);

        if (eventType === 'INSERT') {
            insertRow(sheet, record);
        } else if (eventType === 'UPDATE') {
            updateRow(sheet, record);
        } else if (eventType === 'DELETE') {
            deleteRow(sheet, record.id);
        }

        return ContentService.createTextOutput(JSON.stringify({
            success: true,
            event: eventType
        })).setMimeType(ContentService.MimeType.JSON);

    } catch (error) {
        Logger.log('Error: ' + error.toString());
        return ContentService.createTextOutput(JSON.stringify({
            success: false,
            error: error.toString()
        })).setMimeType(ContentService.MimeType.JSON);
    }
}

// =====================================================
// CRUD Operations
// =====================================================

function insertRow(sheet, record) {
    const row = [
        record.id,
        record.transaction_date,
        record.type === 'infaq_masuk' ? 'Masuk' : 'Keluar',
        record.amount,
        record.description || '',
        record.is_penyisihan ? 'Ya' : 'Tidak',
        record.user_id || '',
        record.user_name || '',
        record.created_at
    ];
    sheet.appendRow(row);

    // Format currency
    const lastRow = sheet.getLastRow();
    sheet.getRange(lastRow, 4).setNumberFormat('Rp #,##0');

    // Color code by type
    if (record.type === 'infaq_masuk') {
        sheet.getRange(lastRow, 3).setBackground('#d1fae5');
    } else {
        sheet.getRange(lastRow, 3).setBackground('#fee2e2');
    }

    // Highlight penyisihan
    if (record.is_penyisihan) {
        sheet.getRange(lastRow, 6).setBackground('#e0e7ff');
    }
}

function updateRow(sheet, record) {
    const rowIndex = findRowById(sheet, record.id);
    if (rowIndex > 0) {
        const row = [
            record.id,
            record.transaction_date,
            record.type === 'infaq_masuk' ? 'Masuk' : 'Keluar',
            record.amount,
            record.description || '',
            record.is_penyisihan ? 'Ya' : 'Tidak',
            record.user_id || '',
            record.user_name || '',
            record.created_at
        ];
        sheet.getRange(rowIndex, 1, 1, row.length).setValues([row]);
        sheet.getRange(rowIndex, 4).setNumberFormat('Rp #,##0');
    }
}

function deleteRow(sheet, id) {
    const rowIndex = findRowById(sheet, id);
    if (rowIndex > 0) {
        sheet.deleteRow(rowIndex);
        Logger.log('Deleted row with ID: ' + id);
    }
}

function findRowById(sheet, id) {
    const data = sheet.getDataRange().getValues();
    for (let i = 1; i < data.length; i++) {
        if (data[i][0] === id) {
            return i + 1; // Sheet rows are 1-indexed
        }
    }
    return -1;
}

// =====================================================
// SYNC ALL - Untuk sinkronisasi manual semua data
// =====================================================
function syncAllFromSupabase() {
    // Ambil data dari Supabase via REST API
    const SUPABASE_URL = 'GANTI_DENGAN_SUPABASE_URL';
    const SUPABASE_ANON_KEY = 'GANTI_DENGAN_SUPABASE_ANON_KEY';

    const response = UrlFetchApp.fetch(
        SUPABASE_URL + '/rest/v1/transactions?select=*,profiles(name)&order=transaction_date.desc',
        {
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': 'Bearer ' + SUPABASE_ANON_KEY
            }
        }
    );

    const transactions = JSON.parse(response.getContentText());

    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    const sheet = ss.getSheetByName(SHEET_NAME);

    // Clear existing data (keep header)
    if (sheet.getLastRow() > 1) {
        sheet.deleteRows(2, sheet.getLastRow() - 1);
    }

    // Insert all transactions
    transactions.forEach(tx => {
        insertRow(sheet, {
            ...tx,
            user_name: tx.profiles?.name || ''
        });
    });

    Logger.log('Synced ' + transactions.length + ' transactions');
}

// =====================================================
// TRIGGER HARIAN - Auto sync setiap hari
// =====================================================
function createDailyTrigger() {
    // Hapus trigger lama
    const triggers = ScriptApp.getProjectTriggers();
    triggers.forEach(trigger => {
        if (trigger.getHandlerFunction() === 'syncAllFromSupabase') {
            ScriptApp.deleteTrigger(trigger);
        }
    });

    // Buat trigger baru: setiap hari jam 6 pagi
    ScriptApp.newTrigger('syncAllFromSupabase')
        .timeBased()
        .everyDays(1)
        .atHour(6)
        .create();

    Logger.log('Daily trigger created!');
}
