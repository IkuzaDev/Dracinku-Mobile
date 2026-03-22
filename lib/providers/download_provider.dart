import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../services/download_service.dart';
import '../services/offline_db.dart';

class DownloadProvider extends ChangeNotifier {
  final OfflineDB _db = OfflineDB();
  final ReceivePort _port = ReceivePort();
  List<Map<String, dynamic>> _downloads = [];
  final Map<String, int> _progress = {}; // taskId -> progress (0-100)
  final Map<String, DownloadTaskStatus> _status = {}; // taskId -> status
  final Map<String, String?> _errors = {}; // taskId -> error message
  bool _isLoading = false;

  List<Map<String, dynamic>> get downloads => _downloads;
  Map<String, int> get progress => _progress;
  Map<String, DownloadTaskStatus> get status => _status;
  Map<String, String?> get errors => _errors;
  bool get isLoading => _isLoading;

  DownloadProvider() {
    _initDownloader();
    loadDownloads();
  }

  void _initDownloader() {
    if (kIsWeb) return;

    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      final String id = data[0];
      final int statusVal = data[1];
      final int progressVal = data[2];

      _progress[id] = progressVal;
      _status[id] = DownloadTaskStatus.fromInt(statusVal);
      
      // Track errors
      if (_status[id] == DownloadTaskStatus.failed) {
        _errors[id] = 'Download failed';
      } else if (_status[id] == DownloadTaskStatus.canceled) {
        _errors[id] = 'Download canceled';
      } else {
        _errors.remove(id);
      }
      
      notifyListeners();
      
      // If completed, refresh the database list to ensure local files are recognized
      if (_status[id] == DownloadTaskStatus.complete) {
        _errors.remove(id);
        loadDownloads();
      }
    });

    FlutterDownloader.registerCallback(DownloadService.downloadCallback);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _port.close();
    super.dispose();
  }

  Future<void> loadDownloads() async {
    if (kIsWeb) return; // Prevent sqflite crash on web preview
    _isLoading = true;
    notifyListeners();

    _downloads = await _db.getDownloads();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> downloadEpisode({
    required String seriesId,
    required String title,
    required int episodeIndex,
    required String videoUrl,
    String? subtitleUrl,
    String? coverUrl,
  }) async {
    if (kIsWeb) return; // Downloads are not supported on web preview

    // Check if this is an HLS stream - warn user that m3u8 cannot be downloaded
    if (DownloadService.isHlsStream(videoUrl)) {
      debugPrint('HLS stream detected - streaming only, download not supported');
      return;
    }

    final result = await DownloadService.enqueueEpisode(
      videoUrl: videoUrl,
      title: title,
      subtitleUrl: subtitleUrl,
    );

    if (result['videoTaskId'] != null) {
      final videoFileName = result['videoFileName'] ?? '$title.mp4';
      final subtitleFileName = result['subtitleFileName'];
      
      final dbData = {
        'id': result['videoTaskId'],
        'seriesId': seriesId,
        'title': title,
        'episodeIndex': episodeIndex,
        'videoPath': '${result["savedDir"]}/$videoFileName',
        'subtitlePath': subtitleUrl != null ? '${result["savedDir"]}/$subtitleFileName' : null,
        'coverUrl': coverUrl,
        'downloadDate': DateTime.now().toIso8601String(),
      };
      
      await _db.insertDownload(dbData);
      await loadDownloads();
    }
  }

  Future<void> deleteDownload(String id) async {
    if (kIsWeb) return;
    await DownloadService.removeDownload(id);
    await _db.deleteDownload(id);
    await loadDownloads();
  }

  Future<String?> getTaskId(String seriesId, int episodeIndex) async {
    final cur = await _db.getDownload(seriesId, episodeIndex);
    return cur?['id'];
  }

  Future<bool> isDownloaded(String seriesId, int episodeIndex) async {
    if (kIsWeb) return false;
    final cur = await _db.getDownload(seriesId, episodeIndex);
    if (cur == null) return false;
    
    // Check if task exists and is completed
    final taskId = cur['id'];
    if (_status.containsKey(taskId)) {
      return _status[taskId] == DownloadTaskStatus.complete;
    }
    
    // If not in memory, check FlutterDownloader directly (could be from previous session)
    final tasks = await FlutterDownloader.loadTasksWithRawQuery(
      query: "SELECT status FROM task WHERE task_id = '$taskId'"
    );
    if (tasks != null && tasks.isNotEmpty) {
      final statusVal = tasks.first.status;
      return statusVal == DownloadTaskStatus.complete;
    }
    
    return false;
  }
}
