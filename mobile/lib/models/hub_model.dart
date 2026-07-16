import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a registered tenant hub inside the `registered_hubs` root
/// collection. The document ID acts as the `parkingHubId` tenant key
/// (e.g. 'HUB-CIQ-JB', 'HUB-KLIA-MAIN').
class HubModel {
  final String id;
  final String name;
  final List<String> zones;

  /// Subscription lifecycle: 'trial', 'active', or 'expired'.
  /// Mobile clients NEVER write this field — it is server-managed only.
  final String status;
  final DateTime? trialStartDate;
  final DateTime? trialEndDate;

  const HubModel({
    required this.id,
    required this.name,
    required this.zones,
    required this.status,
    this.trialStartDate,
    this.trialEndDate,
  });

  bool get isExpired => status.toLowerCase() == 'expired';
  bool get isTrial => status.toLowerCase() == 'trial';

  /// Days remaining in the trial period (0 when not applicable).
  int get trialDaysLeft {
    if (trialEndDate == null) return 0;
    final diff = trialEndDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory HubModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return HubModel(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      zones: (data['zones'] as List<dynamic>?)
              ?.map((z) => z.toString())
              .toList() ??
          const ['Zone A', 'Zone B', 'Zone C'],
      status: (data['status'] as String?) ?? 'trial',
      trialStartDate: (data['trialStartDate'] as Timestamp?)?.toDate(),
      trialEndDate: (data['trialEndDate'] as Timestamp?)?.toDate(),
    );
  }
}
