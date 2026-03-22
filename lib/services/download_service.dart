import 'dart:ui';
import 'dart:isolate';
import 'dart:io';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadService {
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send?.send([id, status, progress]);
  }

  static Future<String> _getDownloadDirectory() async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Request storage permission for Android
      final status = await Permission.storage.request();
      if (status.isGranted) {
        directory = await getExternalStorageDirectory();
      }
      // Fallback to app-specific directory if permission denied
      directory ??= await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      // iOS: Use app documents directory (sandboxed)
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    
    // Create DramaWave folder in app's documents
    final path = '${directory.path}/DramaWave';
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
    String? subtitleUrl,
  }) async {
    final savedDir = await _getDownloadDirectory();
    
    // Sanitize filename to avoid invalid characters
    final sanitizedTitle = _sanitizeFileName(title);
    
    // Determine file extension from URL
    final videoExt = _getFileExtension(videoUrl);
    final subExt = subtitleUrl != null ? _getFileExtension(subtitleUrl) : 'srt';
    
    // Download video
    final videoTaskId = await FlutterDownloader.enqueue(
      url: videoUrl,
      savedDir: savedDir,
      fileName: '$sanitizedTitle$videoExt',
      showNotification: true,
      openFileFromNotification: false,
    );

    // Download subtitle if exists
    String? subTaskId;
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      subTaskId = await FlutterDownloader.enqueue(
        url: subtitleUrl,
        savedDir: savedDir,
        fileName: '$sanitizedTitle.$subExt',
        showNotification: false,
        openFileFromNotification: false,
      );
    }

    return {
      'videoTaskId': videoTaskId,
      'subTaskId': subTaskId,
      'savedDir': savedDir,
      'videoFileName': '$sanitizedTitle$videoExt',
      'subtitleFileName': subtitleUrl != null ? '$sanitizedTitle.$subExt' : null,
    };
  }

  static String _sanitizeFileName(String name) {
    // Remove or replace invalid filename characters
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _getFileExtension(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    
    // Check for common video extensions
    if (path.endsWith('.mp4')) return '.mp4';
    if (path.endsWith('.m3u8')) return '.m3u8';
    if (path.endsWith('.mkv')) return '.mkv';
    if (path.endsWith('.webm')) return '.webm';
    if (path.endsWith('.avi')) return '.avi';
    
    // Default to mp4 for m3u8 or unknown
    if (path.contains('.m3u8')) return '.m3u8';
    return '.mp4';
  }

  // Check if URL is an HLS stream (m3u8)
  static bool isHlsStream(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8') || path.contains('.m3u8');
  }

  static Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
  }

  static Future<void> removeDownload(String taskId) async {
    await FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: true);
  }
  
  // Check if file exists at path
  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }
  
  // Get download task status
  static Future<DownloadTask?> getTask(String taskId) async {
    final tasks = await FlutterDownloader.loadTasksWithRawQuery(
      query: "SELECT * FROM task WHERE task_id = '$taskId'"
    );
    if (tasks != null && tasks.isNotEmpty) {
      return tasks.first;
    }
    return null;
  }
}
