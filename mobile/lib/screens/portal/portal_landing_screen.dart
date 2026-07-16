import 'package:flutter/material.dart';

import '../../app.dart';
import '../../constants/app_theme.dart';

/// Corporate landing portal shown at launch.
///
/// Presents the company brand and lets the user enter one of the three
/// role portals (Admin, Driver, Customer) via premium cards, replacing
/// the previous developer-style dropdown as the primary entry point.
class PortalLandingScreen extends StatelessWidget {
  final ValueChanged<UserRole> onRoleSelected;

  const PortalLandingScreen({super.key, required this.onRoleSelected});

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
          child: Column(
            children: [
              const Spacer(flex: 2),
              // ---------------------------------------------------------
              // Brand mark
              // ---------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(60), width: 2),
                ),
                child: const Icon(
                  Icons.airport_shuttle_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'CIQ Parking Shuttle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Off-Site Parking & Shuttle Transportation',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 14,
                ),
              ),
              const Spacer(flex: 2),
              // ---------------------------------------------------------
              // Role portal cards
              // ---------------------------------------------------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _PortalCard(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin Portal',
                      subtitle: 'Live monitoring, attendance & operations',
                      color: AppTheme.brandGold,
                      onTap: () => onRoleSelected(UserRole.admin),
                    ),
                    const SizedBox(height: 14),
                    _PortalCard(
                      icon: Icons.badge_rounded,
                      title: 'Driver Console',
                      subtitle: 'Clock-in, job queue & shuttle operations',
                      color: AppTheme.brandSecondary,
                      onTap: () => onRoleSelected(UserRole.driver),
                    ),
                    const SizedBox(height: 14),
                    _PortalCard(
                      icon: Icons.person_pin_circle_rounded,
                      title: 'Customer Portal',
                      subtitle: 'Request shuttle & track your ride status',
                      color: const Color(0xFF64B5F6),
                      onTap: () => onRoleSelected(UserRole.customer),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
              Text(
                'Servicing the CIQ Route  •  v1.0.0',
                style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PortalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(20),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withAlpha(120),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
