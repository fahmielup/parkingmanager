import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'constants/app_theme.dart';
import 'models/hub_model.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/customer/customer_request_screen.dart';
import 'screens/driver/driver_shift_screen.dart';
import 'screens/portal/expired_lock_screen.dart';
import 'screens/portal/hub_selector_screen.dart';
import 'screens/portal/portal_landing_screen.dart';
import 'screens/portal/terms_and_conditions_dialog.dart';
import 'services/tenant_service.dart';

/// Available user roles for development testing.
enum UserRole { admin, driver, customer }

/// Root application widget with an integrated role switcher.
class ShuttleApp extends StatefulWidget {
  const ShuttleApp({super.key});

  @override
  State<ShuttleApp> createState() => _ShuttleAppState();
}

class _ShuttleAppState extends State<ShuttleApp> {
  UserRole? _role;
  bool _tncAccepted = false;
  final Future<FirebaseApp> _bootstrap = _initApp();

  static Future<FirebaseApp> _initApp() async {
    final app = await Firebase.initializeApp();
    const useEmulator = bool.fromEnvironment('FIRESTORE_EMULATOR');
    if (useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    }
    // Restore multi-tenant session (cached parkingHubId) if present.
    await TenantService.instance.restoreCachedHub();
    return app;
  }

  Future<void> _ensureTncAccepted(BuildContext context) async {
    if (_tncAccepted) return;
    final alreadyAccepted = await TenantService.instance.isTncAccepted();
    if (alreadyAccepted) {
      setState(() => _tncAccepted = true);
      return;
    }
    if (!context.mounted) return;
    final accepted = await TermsAndConditionsDialog.show(context);
    if (accepted) {
      await TenantService.instance.acceptTnc();
      setState(() => _tncAccepted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIQ Parking Shuttle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      home: FutureBuilder<FirebaseApp>(
        future: _bootstrap,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Firebase init failed: ${snapshot.error}'),
              ),
            );
          }
          // -------------------------------------------------------
          // GATE 1: Terms & Conditions (first launch only)
          // -------------------------------------------------------
          if (!_tncAccepted) {
            return _TncGate(onReady: () => _ensureTncAccepted(context));
          }
          // -------------------------------------------------------
          // GATE 2: Multi-tenant hub selection (parkingHubId)
          // -------------------------------------------------------
          if (!TenantService.instance.hasActiveHub) {
            return HubSelectorScreen(
              onHubSelected: (_) => setState(() {}),
            );
          }
          // -------------------------------------------------------
          // GATE 3: Subscription route guard (server-managed status)
          // -------------------------------------------------------
          return StreamBuilder<HubModel?>(
            stream: TenantService.instance.streamActiveHub(),
            initialData: TenantService.instance.activeHub,
            builder: (context, hubSnap) {
              final hub = hubSnap.data;
              if (hub == null) {
                return HubSelectorScreen(
                  onHubSelected: (_) => setState(() {}),
                );
              }
              if (hub.isExpired) {
                return ExpiredLockScreen(
                  hub: hub,
                  onSwitchHub: () async {
                    await TenantService.instance.clearHub();
                    setState(() => _role = null);
                  },
                );
              }
              if (_role == null) {
                return PortalLandingScreen(
                  onRoleSelected: (role) => setState(() => _role = role),
                );
              }
              return _RoleLayout(
                role: _role!,
                hub: hub,
                onRoleChanged: (role) => setState(() => _role = role),
                onExitPortal: () => setState(() => _role = null),
                onSwitchHub: () async {
                  await TenantService.instance.clearHub();
                  setState(() => _role = null);
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Splash-style gate that triggers the T&C dialog once the frame is built.
class _TncGate extends StatefulWidget {
  final VoidCallback onReady;

  const _TncGate({required this.onReady});

  @override
  State<_TncGate> createState() => _TncGateState();
}

class _TncGateState extends State<_TncGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReady());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.brandPrimary,
      child: const Center(
        child: Icon(Icons.airport_shuttle_rounded,
            size: 72, color: Colors.white),
      ),
    );
  }
}

/// Wraps the active role screen with a top role switcher dropdown.
class _RoleLayout extends StatelessWidget {
  final UserRole role;
  final HubModel hub;
  final ValueChanged<UserRole> onRoleChanged;
  final VoidCallback onExitPortal;
  final VoidCallback onSwitchHub;

  const _RoleLayout({
    required this.role,
    required this.hub,
    required this.onRoleChanged,
    required this.onExitPortal,
    required this.onSwitchHub,
  });

  Widget _roleScreen() {
    switch (role) {
      case UserRole.admin:
        return const AdminDashboardScreen(key: ValueKey('admin'));
      case UserRole.driver:
        return const DriverShiftScreen(key: ValueKey('driver'));
      case UserRole.customer:
        return const CustomerRequestScreen(key: ValueKey('customer'));
    }
  }

  String get _portalTitle {
    switch (role) {
      case UserRole.admin:
        return 'Admin Portal';
      case UserRole.driver:
        return 'Driver Console';
      case UserRole.customer:
        return 'Customer Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.airport_shuttle_rounded, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_portalTitle, overflow: TextOverflow.ellipsis),
                  Text(
                    '${hub.name}${hub.isTrial ? ' • Trial: ${hub.trialDaysLeft} hari lagi' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(190),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<Object>(
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
            tooltip: 'Switch portal',
            onSelected: (value) {
              if (value is UserRole) {
                onRoleChanged(value);
              } else if (value == 'switch_hub') {
                onSwitchHub();
              } else {
                onExitPortal();
              }
            },
            itemBuilder: (_) => [
              ...UserRole.values.map(
                (r) => PopupMenuItem<Object>(
                  value: r,
                  child: Row(
                    children: [
                      Icon(
                        r == UserRole.admin
                            ? Icons.admin_panel_settings_rounded
                            : r == UserRole.driver
                                ? Icons.badge_rounded
                                : Icons.person_pin_circle_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(r.name.toUpperCase()),
                      if (r == role) ...[
                        const Spacer(),
                        const Icon(Icons.check_rounded, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<Object>(
                value: 'switch_hub',
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Tukar Fasiliti'),
                  ],
                ),
              ),
              const PopupMenuItem<Object>(
                value: 'exit',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Exit to Home'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _roleScreen(),
      ),
    );
  }
}
