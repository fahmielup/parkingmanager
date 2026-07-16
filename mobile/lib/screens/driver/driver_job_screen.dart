import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../models/shuttle_request.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../chat/chat_room_screen.dart';

/// Driver console showing the live pending/assigned queue and vehicle identity cards.
class DriverJobScreen extends StatefulWidget {
  final String driverName;
  final String vehicleInfo;

  const DriverJobScreen({
    super.key,
    required this.driverName,
    required this.vehicleInfo,
  });

  @override
  State<DriverJobScreen> createState() => _DriverJobScreenState();
}

class _DriverJobScreenState extends State<DriverJobScreen> {
  final FirestoreService _firestore = FirestoreService();
  final NotificationService _notifications = NotificationService();

  List<ShuttleRequest> _previousRequests = [];
  bool _firstFrame = true;

  @override
  void initState() {
    super.initState();
    _notifications.initialize();
  }

  /// Compare previous pending requests with the new stream snapshot and fire
  /// a foreground notification for every newly arrived pending document.
  void _handleNewPendingAlerts(List<ShuttleRequest> current) {
    if (_firstFrame) {
      _previousRequests = current;
      _firstFrame = false;
      return;
    }

    final prevIds = _previousRequests.map((r) => r.id).toSet();
    final newPending = current
        .where((r) => r.isPending && !prevIds.contains(r.id))
        .toList();

    for (final r in newPending) {
      _notifications.showDriverJobAlert(
        title: 'New Shuttle Request',
        body: '${r.customerName} at ${r.parkingZone} | ${r.carPlate}',
      );
    }
    _previousRequests = current;
  }

  Future<void> _acceptJob(ShuttleRequest request) async {
    await _firestore.updateRequestStatus(
      request.id,
      'assigned',
      driverVehicle: widget.vehicleInfo,
    );
  }

  Future<void> _completeJob(ShuttleRequest request) async {
    await _firestore.updateRequestStatus(request.id, 'completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Tugasan'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Driver Chat',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatRoomScreen(
                    channelId: 'driver_admin',
                    title: 'Driver-to-Admin Chat',
                    senderRole: 'Driver',
                    allowTextInput: false,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ShuttleRequest>>(
        stream: _firestore.streamDriverJobs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleNewPendingAlerts(requests);
          });

          if (requests.isEmpty) {
            return const Center(
              child: Text('No pending or assigned jobs right now.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _JobCard(
                request: request,
                vehicleInfo: widget.vehicleInfo,
                onAccept: request.isPending ? () => _acceptJob(request) : null,
                onComplete: request.isAssigned ? () => _completeJob(request) : null,
              );
            },
          );
        },
      ),
    );
  }
}

/// High-visibility identity card for a single shuttle request.
class _JobCard extends StatelessWidget {
  final ShuttleRequest request;
  final String vehicleInfo;
  final VoidCallback? onAccept;
  final VoidCallback? onComplete;

  const _JobCard({
    required this.request,
    required this.vehicleInfo,
    this.onAccept,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final zoneColor = AppColors.zoneColor(request.parkingZone);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Zone banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: zoneColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              request.parkingZone.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan badge + name
                Row(
                  children: [
                    Chip(
                      backgroundColor: request.parkingPlanType == 'Plan Bulanan'
                          ? Colors.purple.shade100
                          : Colors.orange.shade100,
                      label: Text(
                        request.parkingPlanType,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.customerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // License plate box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    request.carPlate,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Status line
                Row(
                  children: [
                    Icon(
                      request.isAssigned ? Icons.check_circle : Icons.pending,
                      color: request.isAssigned ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      request.isAssigned
                          ? 'Assigned to: $vehicleInfo'
                          : 'Waiting for driver',
                      style: TextStyle(
                        color: request.isAssigned ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  children: [
                    if (onAccept != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: onAccept,
                          icon: const Icon(Icons.check),
                          label: const Text('Accept'),
                        ),
                      ),
                    if (onAccept != null && onComplete != null)
                      const SizedBox(width: 8),
                    if (onComplete != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: onComplete,
                          icon: const Icon(Icons.done_all),
                          label: const Text('Complete'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
