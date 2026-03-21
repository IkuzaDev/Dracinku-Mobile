import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/series_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final res = await ApiService.getHistory();
    if (res.success && res.data != null && mounted) {
      setState(() {
        _history = res.data;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _history.isEmpty
              ? Center(
                  child: Text(
                    'NO PLAYBACK HISTORY',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  separatorBuilder: (context, index) => const Divider(color: AppTheme.border, height: 24),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 120,
                          child: SeriesCard(
                            series: {
                              'title': item['title'],
                              'cover': item['cover'],
                              'chapterCount': item['total_episodes'],
                            },
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text('LAST WATCHED: EP ${item["episode"] ?? 1}', style: const TextStyle(fontFamily: 'monospace', color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (item['progress'] ?? 0) / 100.0,
                                backgroundColor: AppTheme.surfaceLight,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: const Text('RESUME', style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  side: const BorderSide(color: AppTheme.border),
                                  foregroundColor: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
