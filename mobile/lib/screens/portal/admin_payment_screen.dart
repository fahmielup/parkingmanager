import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_theme.dart';
import '../../constants/network_constants.dart';
import '../../models/hub_model.dart';

/// Tenant admin licence renewal screen (ToyyibPay FPX integration).
///
/// SECURITY MODEL: the mobile client NEVER talks to ToyyibPay directly and
/// NEVER holds API secrets. It performs an HTTP POST handshake with the
/// local PC "Parking Manager" backend, which creates the bill server-side
/// and returns the secure `billUrl`. The client then launches the URL in
/// an external browser, steering the admin to the Malaysian FPX banking
/// terminal. Subscription 'status' / 'trialEndDate' flips happen strictly
/// server-side via the ToyyibPay webhook callback, which also logs the
/// transaction into the `financial_transactions` collection for auditing.
class AdminPaymentScreen extends StatefulWidget {
  final HubModel hub;

  const AdminPaymentScreen({super.key, required this.hub});

  @override
  State<AdminPaymentScreen> createState() => _AdminPaymentScreenState();
}

class _AdminPaymentScreenState extends State<AdminPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _adminIdController = TextEditingController();
  bool _busy = false;
  String? _error;

  /// Monthly licence price in cents (RM 250.00).
  static const int _billPriceCents = 25000;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _adminIdController.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${NetworkConstants.baseUrl}/api/toyyibpay/create-bill'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hubId': widget.hub.id,
          'tenantAdminId': _adminIdController.text.trim(),
          'billName': 'Lesen Bulanan - ${widget.hub.name}',
          'billDescription':
              'Pembaharuan langganan sistem Parking Shuttle (30 hari) untuk hub ${widget.hub.id}.',
          'billPrice': _billPriceCents,
          'billEmail': _emailController.text.trim(),
          'billPhone': _phoneController.text.trim(),
        }),
      );

      if (response.statusCode != 200) {
        setState(() => _error =
            'Server menolak permintaan (HTTP ${response.statusCode}). Pastikan backend Parking Manager berjalan di localhost:5000.');
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final billUrl = body['billUrl'] as String?;
      if (billUrl == null || billUrl.isEmpty) {
        setState(() => _error = 'Respons server tidak mengandungi billUrl.');
        return;
      }

      // Steer the tenant admin to the FPX banking terminal externally.
      final launched = await launchUrl(
        Uri.parse(billUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        setState(() => _error = 'Gagal membuka pautan pembayaran.');
      }
    } catch (e) {
      setState(() => _error = 'Ralat rangkaian: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembaharuan Lesen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ------------------------- Price summary card ------------
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.brandPrimary, Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.hub.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                    Text(
                      widget.hub.id,
                      style: TextStyle(
                          color: Colors.white.withAlpha(170), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'RM 250.00',
                      style: TextStyle(
                        color: AppTheme.brandGold,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Langganan 30 hari  •  Pembayaran FPX melalui ToyyibPay',
                      style: TextStyle(
                          color: Colors.white.withAlpha(190), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ------------------------- Billing details ---------------
              TextFormField(
                controller: _adminIdController,
                decoration: const InputDecoration(
                  labelText: 'ID Pentadbir Tenant',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Masukkan ID pentadbir'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Emel Bil',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                validator: (v) => v == null || !v.contains('@')
                    ? 'Masukkan emel yang sah'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. Telefon',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                validator: (v) => v == null || v.trim().length < 9
                    ? 'Masukkan nombor telefon yang sah'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _startPayment,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_rounded),
                label: Text(
                    _busy ? 'Menjana bil selamat...' : 'Bayar Melalui ToyyibPay'),
              ),
              const SizedBox(height: 16),
              Text(
                'Nota: Bayaran yang disahkan adalah tidak boleh dikembalikan (non-refundable). Sistem akan diaktifkan semula secara automatik sebaik pengesahan diterima daripada ToyyibPay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
