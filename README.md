# ProxView Mobile (Flutter)

**ProxView** adalah aplikasi mobile multi-platform berbasis **Flutter** untuk **Monitoring Infrastruktur Proxmox VE, Target Jaringan (ICMP Ping & TCP Socket), Analitik Kinerja SLA (ITIL), serta Sistem Penanganan Tiket Insiden & Panggilan Darurat (Emergency Call)** secara *real-time*.

---

## Arsitektur & Struktur Proyek

Aplikasi ini dibangun menggunakan pola arsitektur **MVVM (Model–View–ViewModel)** dengan state management **Provider**:

```text
lib/
├── core/
│   ├── theme/
│   │   └── app_theme.dart              # Tema adaptif Light/Dark mode & warna indikator status
│   └── utils/
│       └── formatters.dart             # Formatter tanggal, waktu, dan durasi
├── models/
│   ├── alert_incident_model.dart       # Model Alert, Tiket Insiden (#INC-YYYY-XXXX), & Statistik
│   ├── analytics_model.dart            # Model Metrik SLA ITIL (Availability, MTTR, Uptime/Downtime)
│   ├── dashboard_model.dart            # Model Status Global & Ringkasan Dashboard
│   ├── log_model.dart                  # Model Task Log, Cluster Log Proxmox, & System Audit Log
│   ├── network_target_model.dart       # Model Target ICMP Ping / TCP Socket & Riwayat Latency
│   ├── proxmox_model.dart              # Model Server, Node Fisik, VM (QEMU), Container (LXC), & Storage
│   └── user_model.dart                 # Model Pengguna & Role (Teknisi / Kepala Bidang)
├── services/
│   ├── api_service.dart                # HTTP Client (Dio) ProxViewApiService (/api/mobile/v1)
│   ├── notification_service.dart       # Local Notification & Full-Screen Emergency Call Intent
│   └── storage_service.dart            # Penyimpanan Token (FlutterSecureStorage) & Preferensi
├── viewmodels/
│   ├── alert_incident_viewmodel.dart   # State & polling insiden aktif, join/resolve tiket
│   ├── analytics_viewmodel.dart        # State analitik SLA (24h, 7d, 30d)
│   ├── auth_viewmodel.dart             # State otentikasi 3-Faktor & manajemen sesi
│   ├── dashboard_viewmodel.dart        # State ringkasan metrik & grafik RRD cluster
│   ├── log_viewmodel.dart              # State log task, cluster, & audit internal
│   ├── network_viewmodel.dart          # State daftar target jaringan & riwayat latency
│   └── proxmox_viewmodel.dart          # State cluster Proxmox, node, VM, LXC, & storage
├── views/
│   ├── alerts_incidents_view.dart      # Halaman Alert Aktif, Tiket Insiden, & Riwayat
│   ├── common_widgets.dart             # Komponen UI reusable & PulseLogoPainter ProxView
│   ├── dashboard_view.dart             # Halaman Dashboard utama (Teknisi & Kepala Bidang)
│   ├── emergency_call_view.dart        # Layar alarm panggilan darurat penuh (action_type: Call)
│   ├── login_view.dart                 # Halaman Login Otentikasi 3-Faktor
│   ├── logs_view.dart                  # Halaman Log Task, Cluster Proxmox, & Audit Sistem
│   ├── main_shell_view.dart            # Navigasi utama berbasis Role & Background Polling
│   ├── network_targets_view.dart       # Halaman Monitoring Target ICMP Ping & TCP Socket
│   ├── proxmox_view.dart               # Halaman Detail Node, VM, LXC, & Storage Proxmox VE
│   ├── resource_view.dart              # Halaman Ringkasan Resource (khusus Kepala Bidang)
│   ├── settings_view.dart              # Halaman Profil, Tema Gelap/Terang, & Endpoint Server
│   ├── sla_analytics_view.dart         # Halaman Analitik SLA & Grafik Kinerja ITIL
│   └── splash_view.dart                # Splash Screen & Auto-Login pengecekan sesi
└── main.dart                           # Entry point aplikasi ProxView
```

---

## Fitur Utama

1. **Otentikasi 3-Faktor & Multi-Role (`Teknisi` & `Kepala Bidang`)**:
   - Validasi `Username`, `Password`, dan `API Token` (64-karakter hex dari Web Admin ProxView).
   - Tampilan menu dan aksi menyesuaikan hak akses pengguna secara otomatis.
2. **Monitoring Cluster Proxmox VE Real-Time**:
   - Pemantauan metrik Node Fisik (CPU, RAM, I/O Delay, Load Average, Network RX/TX, Uptime).
   - Pemantauan Virtual Machine (`QEMU`), Container (`LXC`), serta kapasitas `Storage`.
3. **Monitoring Jaringan (ICMP Ping & TCP Socket)**:
   - Pemantauan status `UP`/`DOWN` dan grafik riwayat *latency* 20 titik terakhir per target.
4. **Manajemen Insiden & Panggilan Darurat (`Emergency Call`)**:
   - Polling otomatis gangguan aktif beserta notifikasi lokal dan layar dering darurat penuh (`action_type == "Call"`).
   - Siklus penanganan tiket terintegrasi: **Tangani Gangguan (`Join`)** hingga **Tandai Selesai (`Resolve`)** saat target berstatus `RECOVERED`.
5. **Analitik Kinerja Sistem (ITIL SLA)**:
   - Perhitungan *Availability (%)*, *MTTR*, *Total Uptime*, *Total Downtime*, dan visualisasi grafik periodik (`24h`, `7d`, `30d`).

---

## Menjalankan Proyek

```bash
# 1. Unduh seluruh dependensi paket
flutter pub get

# 2. Jalankan analisis kode statis
flutter analyze

# 3. Jalankan aplikasi
flutter run
```
