# Infaq App

Aplikasi manajemen infaq sekolah dengan SvelteKit + Supabase.

## Tech Stack

- **Frontend**: SvelteKit + TypeScript
- **Backend**: Supabase (Auth + Database)
- **PWA**: Vite PWA Plugin

## Quick Start

### 1. Setup Database di Supabase

Buka **SQL Editor** di Supabase Dashboard dan jalankan isi file `supabase-schema.sql`.

### 2. Buat Admin User

Di Supabase Dashboard → **Authentication** → **Users** → **Add User**:
- Email: `admin@infaq.app`
- Password: `admin123`

Lalu di **SQL Editor**, jalankan:
```sql
UPDATE profiles 
SET role = 'admin', can_view_penyisihan = true 
WHERE email = 'admin@infaq.app';
```

### 3. Jalankan Frontend

```bash
cd frontend
npm install
npm run dev
```

Buka http://localhost:3000

## User Roles

| Role | Input Infaq | Pengeluaran | Laporan | Penyisihan |
|------|-------------|-------------|---------|------------|
| Admin | ✅ | ✅ | ✅ | ✅ |
| Guru | ✅ | ✅ | ✅ | ⚠️ |
| Kepala Sekolah | ❌ | ❌ | ✅ | ❌ |

⚠️ = Hanya guru dengan `can_view_penyisihan = true`

## Environment Variables

File `.env` di folder `frontend/`:
```
PUBLIC_SUPABASE_URL=https://your-project.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```
