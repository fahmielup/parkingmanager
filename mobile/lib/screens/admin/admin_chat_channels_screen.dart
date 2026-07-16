import 'package:flutter/material.dart';

import '../chat/chat_room_screen.dart';

/// Navigation hub for the 3 admin chat pathways.
class AdminChatChannelsScreen extends StatelessWidget {
  const AdminChatChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Chat Channels'),
        backgroundColor: Colors.indigo,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildChannelTile(
            context: context,
            title: 'Customer-to-Admin',
            channelId: 'customer_admin',
            icon: Icons.support_agent,
            color: Colors.teal,
          ),
          _buildChannelTile(
            context: context,
            title: 'Driver-to-Admin',
            channelId: 'driver_admin',
            icon: Icons.local_taxi,
            color: Colors.deepPurple,
          ),
          _buildChannelTile(
            context: context,
            title: 'Customer-to-Driver',
            channelId: 'customer_driver',
            icon: Icons.swap_horiz,
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
                senderRole: 'Admin',
                allowTextInput: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
