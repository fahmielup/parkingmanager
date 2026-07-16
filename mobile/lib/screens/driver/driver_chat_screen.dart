import 'package:flutter/material.dart';

import '../chat/chat_room_screen.dart';

/// Driver chat launcher with links to the allowed channels.
/// Text typing is disabled on these channels for road safety.
class DriverChatScreen extends StatelessWidget {
  const DriverChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Chat'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildChannelTile(
            context: context,
            title: 'Driver-to-Admin',
            channelId: 'driver_admin',
            icon: Icons.support_agent,
            color: Colors.deepPurple,
          ),
          _buildChannelTile(
            context: context,
            title: 'Customer-to-Driver',
            channelId: 'customer_driver',
            icon: Icons.person_pin,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile({
    required BuildContext context,
    required String title,
    required String channelId,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                channelId: channelId,
                title: title,
                senderRole: 'Driver',
                allowTextInput: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
