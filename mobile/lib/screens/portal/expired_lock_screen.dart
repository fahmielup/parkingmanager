import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import '../../models/hub_model.dart';
import 'admin_payment_screen.dart';

/// Military-grade route-guard lock screen.
///
/// Rendered when the active tenant hub's subscription `status` is
/// 'expired'. All downstream mobile streams are blocked by the app-level
/// route guard; the only way forward is licence renewal via ToyyibPay
/// (tenant admins) or switching facility.
class ExpiredLockScreen extends StatelessWidget {
  final HubModel hub;
  final VoidCallback onSwitchHub;

  const ExpiredLockScreen({
    super.key,
    required this.hub,
    required this.onSwitchHub,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7F1D1D), Color(0xFF450A0A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withAlpha(70), width: 2),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        size: 56, color: Colors.white),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'AKSES DISEKAT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Langganan bagi hub "${hub.name}" (${hub.id}) telah tamat tempoh.\n\nSemua akses kepada sistem shuttle — permintaan pelanggan, kenderaan syarikat & kehadiran pemandu — disekat sehingga pembaharuan lesen dibuat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withAlpha(210),
                        fontSize: 14,
                        height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.brandGold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AdminPaymentScreen(hub: hub),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Perbaharui Lesen (ToyyibPay)'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: onSwitchHub,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Tukar Fasiliti'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Pembayaran disahkan akan mengaktifkan semula sistem\nsecara automatik dalam masa nyata.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withAlpha(140), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
