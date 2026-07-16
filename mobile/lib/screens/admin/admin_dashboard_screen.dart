import 'package:flutter/material.dart';
import 'admin_attendance_screen.dart';
import 'admin_map_monitor_screen.dart';
import 'admin_chat_channels_screen.dart';

/// Admin landing page with a grid of navigation cards.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildCard(
              context: context,
              icon: Icons.check_circle,
              label: 'Driver Attendance',
              color: Colors.blue,
              destination: const AdminAttendanceScreen(),
            ),
            _buildCard(
              context: context,
              icon: Icons.map,
              label: 'Live Map Monitor',
              color: Colors.green,
              destination: const AdminMapMonitorScreen(),
            ),
            _buildCard(
              context: context,
              icon: Icons.chat,
              label: 'Chat Channels',
              color: Colors.orange,
              destination: const AdminChatChannelsScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required Widget destination,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withAlpha(217), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
