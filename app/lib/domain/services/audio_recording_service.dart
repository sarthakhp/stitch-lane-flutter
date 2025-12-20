import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  static final AudioRecorder _recorder = AudioRecorder();
  static bool _isRecording = false;

  static Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  static Future<String?> startRecording(String measurementId) async {
    try {
      if (_isRecording) {
        await stopRecording();
      }

      final hasPermission = await AudioRecordingService.hasPermission();
      if (!hasPermission) {
        return null;
      }

      final filePath = await getAudioFilePath(measurementId);

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _isRecording = true;
      return filePath;
    } catch (e) {
      _isRecording = false;
      rethrow;
    }
  }

  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        return null;
      }

      final path = await _recorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      _isRecording = false;
      rethrow;
    }
  }

  static Future<void> deleteRecording(String measurementId) async {
    try {
      final filePath = await getAudioFilePath(measurementId);
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> getAudioFilePath(String measurementId) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/measurement_$measurementId.m4a';
  }

  static Future<String> getTemporaryAudioFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/new_measurement_audio.m4a';
  }

  static Future<String?> renameTemporaryAudio(String measurementId) async {
    try {
      final tempPath = await getTemporaryAudioFilePath();
      final tempFile = File(tempPath);

      if (!await tempFile.exists()) {
        return null;
      }

      final newPath = await getAudioFilePath(measurementId);
      final newFile = File(newPath);

      if (await newFile.exists()) {
        await newFile.delete();
      }

      await tempFile.rename(newPath);
      return newPath;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> deleteTemporaryAudio() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final tempFile = File('${directory.path}/temp_order_transcription.m4a');

      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  static bool get isRecording => _isRecording;

  static Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _recorder.dispose();
  }
}

