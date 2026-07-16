import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'tenant_service.dart';

/// Manages Push-to-Talk recording and audio playback for walkie-talkie chat.
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _recordingPath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Starts recording a compressed audio file in a temp directory.
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied.');
    }

    final Directory tempDir = await getTemporaryDirectory();
    final String fileName = 'ptt_${const Uuid().v4()}.m4a';
    final String path = '${tempDir.path}/$fileName';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
      ),
      path: path,
    );
    _recordingPath = path;
    _isRecording = true;
  }

  /// Stops recording and returns the local file path.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    return path ?? _recordingPath;
  }

  /// Uploads the local audio file to Firebase Storage under the
  /// tenant-scoped path `walkie_talkie/{parkingHubId}/{channelId}/`
  /// and returns the download URL.
  Future<String> uploadAudioFile(String localPath, String channelId) async {
    final File file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('Recorded audio file does not exist.');
    }

    final String hubId = TenantService.instance.activeHubId;
    final String fileName = '${const Uuid().v4()}.m4a';
    final Reference ref = FirebaseStorage.instance
        .ref()
        .child('walkie_talkie')
        .child(hubId.isEmpty ? 'default' : hubId)
        .child(channelId)
        .child(fileName);

    await ref.putFile(file);
    final String url = await ref.getDownloadURL();
    return url;
  }

  /// Plays a remote audio URL via audioplayers.
  Future<void> playAudio(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
