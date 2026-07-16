import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';

/// First-launch Terms & Conditions gate.
///
/// Every user (Admin, Driver, or Customer) must tap "Saya Setuju" before
/// any form or dashboard can be opened for the first time. Acceptance is
/// persisted via [TenantService.acceptTnc].
class TermsAndConditionsDialog extends StatelessWidget {
  const TermsAndConditionsDialog({super.key});

  /// Shows the dialog; resolves to true only when the user accepts.
  static Future<bool> show(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TermsAndConditionsDialog(),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: AppTheme.brandPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Terma & Syarat Perkhidmatan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          height: 420,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('BAHAGIAN A: SYARIKAT PENYEWA / PENGENDALI PARKIR (B2B)'),
                  _Clause('1. Pendaftaran Akaun Hub & Syif Kakitangan',
                      'Syarikat Penyewa bertanggungjawab sepenuhnya untuk menjaga kerahsiaan akaun pentadbir (Admin) dan kod pengenalan hub (parkingHubId) yang diberikan. Pemandu di bawah seliaan Syarikat Penyewa diwajibkan melakukan pendaftaran masuk syif (Clock-In) dan memilih kenderaan yang betul bagi memastikan ketelusan rekod kehadiran dan audit sistem.'),
                  _Clause('2. Pelan Percubaan (1-Month Free Trial) & Tempoh Luput',
                      'Pihak Syarikat Utama menawarkan tempoh percubaan percuma selama satu (1) bulan (30 hari) kepada Syarikat Penyewa baharu. Apabila tempoh 30 hari tamat, sistem akan menukar status akaun kepada "Tamat Tempoh" (Expired) secara automatik. Kegagalan membuat bayaran pembaharuan lesen akan menyebabkan sekatan akses penuh kepada papan pemuka Admin Mobile dan Pemandu.'),
                  _Clause('3. Sistem Pembayaran Selamat (ToyyibPay)',
                      'Semua bayaran langganan bulanan (berjumlah RM 250.00 atau mengikut pakej semasa) hendaklah dibuat secara terus melalui gerbang pembayaran ToyyibPay yang disepadukan di dalam sistem. Bayaran yang telah disahkan berjaya adalah tidak boleh dikembalikan (non-refundable). Sistem akan diaktifkan semula secara automatik dalam masa nyata sebaik sahaja pengesahan pembayaran diterima daripada ToyyibPay.'),
                  _Clause('4. Keselamatan Pemanduan & PTT Walkie-Talkie',
                      'Syarikat Penyewa wajib memastikan pemandu mereka mematuhi undang-undang jalan raya Malaysia. Aplikasi ini telah menyediakan fungsi Push-to-Talk (PTT) dan Butang Pilihan Pantas (Quick Replies) bagi menyekat penggunaan papan kekunci manual semasa memandu. Pihak Syarikat Utama tidak akan bertanggungjawab atas sebarang kemalangan, saman, atau liabiliti yang berlaku akibat kecuaian pemandu semasa mengendalikan peranti.'),
                  SizedBox(height: 12),
                  _SectionTitle('BAHAGIAN B: PELANGGAN / PENUMPANG AWAM (B2C)'),
                  _Clause('1. Ketepatan Maklumat Kenderaan & Nama',
                      'Pelanggan wajib memastikan Nama Penuh dan Nombor Plat Kenderaan yang dimasukkan ke dalam borang adalah betul dan sepadan dengan kenderaan yang diletakkan di premis parkir. Maklumat ini digunakan oleh pemandu untuk pengesahan visual (Visual Identity Verification). Pemandu berhak menolak untuk mengambil penumpang sekiranya nombor plat atau identiti didapati tidak sepadan dengan data sistem.'),
                  _Clause('2. Perkongsian Lokasi GPS Latar Belakang',
                      'Untuk membolehkan fungsi penjejakan jarak (Proximity Detection) berfungsi dengan baik bagi tujuan logistik, Aplikasi akan meminta kebenaran untuk mengakses lokasi GPS peranti anda, termasuk semasa Aplikasi diletakkan di latar belakang (background). Data GPS ini digunakan semata-mata untuk tujuan operasi penghantaran van dan tidak akan dijual atau dikongsi kepada mana-mana pihak ketiga yang tidak berkaitan.'),
                  _Clause('3. Polisi Privasi Data & Peranti Pelanggan',
                      'Aplikasi ini direka secara privasi-sentrik. Pelanggan awam tidak diberikan akses untuk melihat peta pergerakan GPS pemandu secara langsung demi menjaga privasi dan keselamatan pemandu. Pelanggan bersetuju bahawa status anggaran ketibaan van (ETA) yang dipaparkan adalah berdasarkan keadaan trafik semasa ke CIQ dan boleh berubah dari semasa ke semasa. Pihak Syarikat Utama tidak bertanggungjawab sekiranya pelanggan terlewat akibat kesesakan lalu lintas luar kawalan di laluan CIQ.'),
                  _Clause('4. Penyalahgunaan Fungsi Sembang (Chat & Voice)',
                      'Fungsi sembang masa nyata dan perakam suara walkie-talkie disediakan semata-mata untuk urusan logistik penyeberangan sahaja. Sebarang bentuk penyalahgunaan seperti penghantaran mesej berunsur lucah, ugutan, penghinaan, atau gangguan kepada pemandu atau pentadbir akan menyebabkan akaun peranti pelanggan disekat (banned) daripada menggunakan Aplikasi ini secara kekal.'),
                  SizedBox(height: 12),
                  _SectionTitle('BAHAGIAN C: HAD LIABILITI AM (PENAFIAN)'),
                  _Clause('Ketersediaan Sistem',
                      'Pihak Syarikat Utama sentiasa memastikan kestabilan pelayan Firebase dan rangkaian API. Walau bagaimanapun, kami tidak menjamin bahawa Aplikasi akan sentiasa bebas daripada gangguan teknikal atau luar kawalan (seperti gangguan telco internet).'),
                  _Clause('Hak Pengisytiharan',
                      'Pihak Syarikat Utama berhak untuk meminda, menambah, atau menukar mana-mana terma di dalam dokumen ini pada bila-bila masa tanpa notis awal.'),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Saya Setuju'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppTheme.brandPrimary,
        ),
      ),
    );
  }
}

class _Clause extends StatelessWidget {
  final String title;
  final String body;
  const _Clause(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(body,
              style: TextStyle(
                  fontSize: 12, height: 1.5, color: Colors.grey.shade800)),
        ],
      ),
    );
  }
}
