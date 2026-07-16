import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants/chat_quick_replies.dart';
import '../../models/chat_message.dart';
import '../../services/audio_service.dart';
import '../../services/firestore_service.dart';

/// Shared chat room for all three conversational pathways.
/// [allowTextInput] is false for the driver console to enforce road safety.
class ChatRoomScreen extends StatefulWidget {
  final String channelId;
  final String title;
  final String senderRole;
  final bool allowTextInput;

  const ChatRoomScreen({
    super.key,
    required this.channelId,
    required this.title,
    required this.senderRole,
    required this.allowTextInput,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final FirestoreService _firestore = FirestoreService();
  final AudioService _audio = AudioService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRecording = false;
  bool _isUploading = false;

  /// Walkie-talkie receiver state: -1 means the initial history load has
  /// not completed yet (existing messages must NOT trigger the buzz).
  int _knownMessageCount = -1;

  @override
  void initState() {
    super.initState();
    _firestore.ensureChatChannelExists(widget.channelId);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;
    final message = ChatMessage(
      id: '',
      sender: widget.senderRole,
      text: text.trim(),
      type: 'text',
      timestamp: Timestamp.now(),
    );
    await _firestore.sendMessage(widget.channelId, message);
    _textController.clear();
    _scrollToBottom();
  }

  Future<void> _sendQuickReply(String text) async {
    final message = ChatMessage(
      id: '',
      sender: widget.senderRole,
      text: text,
      type: 'quick_reply',
      timestamp: Timestamp.now(),
    );
    await _firestore.sendMessage(widget.channelId, message);
  }

  Future<void> _startRecording() async {
    try {
      await _audio.startRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnack('Recording error: $e');
    }
  }

  Future<void> _stopRecordingAndUpload() async {
    setState(() => _isRecording = false);
    final path = await _audio.stopRecording();
    if (path == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await _audio.uploadAudioFile(path, widget.channelId);
      final message = ChatMessage(
        id: '',
        sender: widget.senderRole,
        text: 'Voice message',
        type: 'audio',
        mediaUrl: url,
        timestamp: Timestamp.now(),
      );
      await _firestore.sendMessage(widget.channelId, message);
    } catch (e) {
      _showSnack('Upload error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  /// WALKIE-TALKIE BUZZ: when a new incoming message arrives while this
  /// room is open, vibrate the device (buzz) and auto-play voice audio
  /// hands-free - exactly like a real walkie-talkie receiver. The sender's
  /// own messages never trigger the buzz.
  Future<void> _handleIncoming(List<ChatMessage> messages) async {
    if (_knownMessageCount == -1 || messages.length < _knownMessageCount) {
      _knownMessageCount = messages.length;
      return;
    }
    if (messages.length == _knownMessageCount) return;

    final newMessages = messages.sublist(_knownMessageCount);
    _knownMessageCount = messages.length;

    for (final m in newMessages) {
      if (m.sender == widget.senderRole) continue;

      // Buzz: double vibration pulse like a PTT radio squelch.
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.heavyImpact();

      if (m.isAudio && m.mediaUrl != null) {
        // Auto-play the incoming transmission hands-free.
        try {
          await _audio.playAudio(m.mediaUrl!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('\u{1F4FB} Transmisi masuk - dimainkan automatik'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (_) {
          // Playback failure is non-fatal; bubble still shows a play button.
        }
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          if (!widget.allowTextInput)
            Container(
              width: double.infinity,
              color: Colors.amber.shade100,
              padding: const EdgeInsets.all(8),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Typing is disabled while driving. Use quick replies or push-to-talk.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (_isRecording)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'SEDANG MERAKAM...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _firestore.streamMessages(widget.channelId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                  _handleIncoming(messages);
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),
          if (!widget.allowTextInput) _buildQuickReplyBar(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.sender == widget.senderRole;
    final timeStr = DateFormat('HH:mm').format(message.timestamp.toDate());

    Widget content;
    if (message.isAudio && message.mediaUrl != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => _audio.playAudio(message.mediaUrl!),
          ),
          const Icon(Icons.graphic_eq, size: 18),
          const SizedBox(width: 6),
          const Text('Transmisi suara'),
        ],
      );
    } else if (message.type == 'quick_reply') {
      content = Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: Text(
          message.text ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    } else {
      content = Text(message.text ?? '');
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            content,
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplyBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ChatQuickReplies.driverReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final text = ChatQuickReplies.driverReplies[index];
          return ActionChip(
            label: Text(text),
            backgroundColor: Colors.amber.shade100,
            onPressed: () => _sendQuickReply(text),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Expanded(
              child: widget.allowTextInput
                  ? TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: _sendText,
                    )
                  : Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Quick reply / PTT only',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            if (widget.allowTextInput)
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendText(_textController.text),
              ),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecordingAndUpload(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.indigo,
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
