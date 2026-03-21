import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  static Future<String> _getDownloadDirectory() async {
    // For Android/iOS specific storage
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    
    final path = '${directory!.path}/DramaWave';
    final savedDir = Directory(path);
    if (!await savedDir.exists()) {
      await savedDir.create(recursive: true);
    }
    return savedDir.path;
  }

  // Enqueue a video and its subtitle
  static Future<Map<String, String?>> enqueueEpisode({
    required String videoUrl,
    required String title,
    String? subtitleUrl, // Ensure subtitle is handled as requested
  }) async {
    final savedDir = await _getDownloadDirectory();
    
    // Download video
    final videoTaskId = await FlutterDownloader.enqueue(
      url: videoUrl,
      savedDir: savedDir,
      fileName: '$title.mp4',
      showNotification: true,
      openFileFromNotification: false,
    );

    // Download subtitle if exists
    String? subTaskId;
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      subTaskId = await FlutterDownloader.enqueue(
        url: subtitleUrl,
        savedDir: savedDir,
        fileName: '$title.srt', // Assuming srt format, can be adjusted
        showNotification: false,
        openFileFromNotification: false,
      );
    }

    return {
      'videoTaskId': videoTaskId,
      'subTaskId': subTaskId,
      'savedDir': savedDir,
    };
  }

  static Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  static Future<void> removeDownload(String taskId) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
  }
}
