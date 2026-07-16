import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../services/firestore_service.dart';

/// Admin screen that streams real-time driver clock-ins and vehicle assignments.
class AdminAttendanceScreen extends StatelessWidget {
  const AdminAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Attendance'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<List<AttendanceModel>>(
        stream: service.streamAttendance(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = snapshot.data!;
          if (records.isEmpty) {
            return const Center(child: Text('No drivers currently on shift.'));
          }

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final timeStr = DateFormat('dd MMM yyyy, HH:mm').format(
                record.timestamp.toDate(),
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: record.status == 'Active'
                        ? Colors.green
                        : Colors.grey,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(record.driverName),
                  subtitle: Text('Clocked in: $timeStr'),
                  trailing: Chip(
                    backgroundColor: Colors.blue.shade100,
                    label: Text(record.vehicleInfo),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
