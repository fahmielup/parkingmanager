import 'package:flutter/material.dart';

import '../../constants/app_theme.dart';
import '../../models/hub_model.dart';
import '../../services/tenant_service.dart';

/// Multi-tenant onboarding entry screen.
///
/// Shown when no active `parkingHubId` is cached locally. Lets the user
/// choose their facility from a live dropdown of `registered_hubs`, or
/// enter a hub code manually (mimicking a static QR deep-link setup,
/// e.g. 'HUB-CIQ-JB', 'HUB-KLIA-MAIN').
class HubSelectorScreen extends StatefulWidget {
  final ValueChanged<HubModel> onHubSelected;

  const HubSelectorScreen({super.key, required this.onHubSelected});

  @override
  State<HubSelectorScreen> createState() => _HubSelectorScreenState();
}

class _HubSelectorScreenState extends State<HubSelectorScreen> {
  final TenantService _tenant = TenantService.instance;
  final TextEditingController _codeController = TextEditingController();
  String? _selectedHubId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _activateHub({String? hubIdFromDropdown, String? code}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final manualCode = code?.trim() ?? '';
      final hubId =
          manualCode.isNotEmpty ? manualCode : (hubIdFromDropdown ?? '');
      if (hubId.isEmpty) {
        setState(() => _error = 'Sila pilih hub atau masukkan kod hub.');
        return;
      }
      final resolved = await _tenant.selectHubById(hubId);
      if (resolved == null) {
        setState(() =>
            _error = 'Kod hub "$hubId" tidak berdaftar. Semak dan cuba lagi.');
        return;
      }
      widget.onHubSelected(resolved);
    } catch (e) {
      setState(() => _error = 'Ralat sambungan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.brandPrimary, Color(0xFF071F4A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white.withAlpha(60), width: 2),
                    ),
                    child: const Icon(Icons.hub_rounded,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Pilih Fasiliti Parkir Anda',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Setiap syarikat pengendali mempunyai hub tersendiri.\nPilih dari senarai atau imbas kod hub anda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withAlpha(180), fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // -----------------------------------------------------
                  // Card containing the selector form
                  // -----------------------------------------------------
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Live dropdown from `registered_hubs`
                        StreamBuilder<List<HubModel>>(
                          stream: _tenant.streamHubs(),
                          builder: (context, snapshot) {
                            final hubs = snapshot.data ?? const <HubModel>[];
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                hubs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            if (hubs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Tiada hub berdaftar buat masa ini.\nGunakan kod hub manual di bawah.',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            final validSelection = hubs
                                .any((h) => h.id == _selectedHubId);
                            return DropdownButtonFormField<String>(
                              initialValue:
                                  validSelection ? _selectedHubId : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Fasiliti Berdaftar',
                                prefixIcon: Icon(Icons.location_city_rounded),
                              ),
                              items: hubs
                                  .map((h) => DropdownMenuItem(
                                        value: h.id,
                                        child: Text(
                                          '${h.name} (${h.id})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (id) =>
                                  setState(() => _selectedHubId = id),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ATAU',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Manual hub code entry (QR deep-link style)
                        TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Kod Hub (cth: HUB-CIQ-JB)',
                            prefixIcon: Icon(Icons.qr_code_rounded),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _activateHub(
                                    hubIdFromDropdown: _selectedHubId,
                                    code: _codeController.text,
                                  ),
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(_busy ? 'Menyambung...' : 'Masuk Hub'),
                        ),
                      ],
                    ),
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
