import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/download_service.dart';
import '../services/offline_db.dart';

class DownloadProvider extends ChangeNotifier {
  final OfflineDB _db = OfflineDB();
  List<Map<String, dynamic>> _downloads = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get downloads => _downloads;
  bool get isLoading => _isLoading;

  DownloadProvider() {
    loadDownloads();
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

    final result = await DownloadService.enqueueEpisode(
      videoUrl: videoUrl,
      title: title,
      subtitleUrl: subtitleUrl,
    );

    if (result['videoTaskId'] != null) {
      final dbData = {
        'id': result['videoTaskId'],
        'seriesId': seriesId,
        'title': title,
        'episodeIndex': episodeIndex,
        'videoPath': '${result["savedDir"]}/$title.mp4',
        'subtitlePath': subtitleUrl != null ? '${result["savedDir"]}/$title.srt' : null,
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

  Future<bool> isDownloaded(String seriesId, int episodeIndex) async {
    if (kIsWeb) return false;
    final cur = await _db.getDownload(seriesId, episodeIndex);
    return cur != null;
  }
}
