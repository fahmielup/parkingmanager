import 'package:cloud_firestore/cloud_firestore.dart';

/// One message inside a Firestore [chats/{channelId}/messages] sub-collection.
class ChatMessage {
  final String id;
  final String sender;
  final String? text;
  final String type; // 'text' | 'audio' | 'quick_reply'
  final String? mediaUrl;
  final Timestamp timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    this.text,
    required this.type,
    this.mediaUrl,
    required this.timestamp,
  });

  bool get isAudio => type == 'audio';

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      sender: data['sender'] as String? ?? 'Unknown',
      text: data['text'] as String?,
      type: data['type'] as String? ?? 'text',
      mediaUrl: data['mediaUrl'] as String?,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
    };
  }
}
