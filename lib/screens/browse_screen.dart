import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/platform_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/series_card.dart';
import 'series_detail_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  Map<String, List<dynamic>> _groupedTabs = {};
  Map<String, dynamic> _filters = {};
  List<dynamic> _series = [];
  bool _isLoading = true;
  bool _isFeedLoading = false;
  bool _hasMore = true;
  Map<String, dynamic>? _pageInfo;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Listen to platform changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final platformProv = Provider.of<PlatformProvider>(context, listen: false);
      platformProv.addListener(_onPlatformChange);
      _loadTabs();
    });
  }

  void _onPlatformChange() {
    if (mounted) {
      _loadTabs();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    
    // Remove listener
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    platformProv.removeListener(_onPlatformChange);
    
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isFeedLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadTabs() async {
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    setState(() => _isLoading = true);
    
    final res = await ApiService.tablist(platformProv.activePlatform, lang: platformProv.activeLanguage);
    if (res.success && res.data != null) {
      if (mounted) {
        final List<dynamic> allTabs = res.data;
        Map<String, List<dynamic>> grouped = {};
        Map<String, dynamic> initialFilters = {};
        
        for (var t in allTabs) {
          final type = t['type'] as String;
          grouped.putIfAbsent(type, () => []).add(t);
        }
        
        for (var type in grouped.keys) {
          initialFilters[type] = grouped[type]![0];
        }

        setState(() {
          _groupedTabs = grouped;
          _filters = initialFilters;
          _isLoading = false;
        });
        if (_filters.isNotEmpty) _loadData();
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    if (_filters.isEmpty) return;
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    
    setState(() {
      _isFeedLoading = true;
      _series = [];
      _hasMore = true;
    });

    // Use primary filter
    final primary = _filters.values.first;
    final body = {
      'type': primary['type'],
      'key': primary['tab_key'],
      'position': primary['position_index'],
      'page': 1,
    };

    final res = await ApiService.tabdata(platformProv.activePlatform, body, lang: platformProv.activeLanguage);
    if (res.success && res.data != null && mounted) {
      final items = res.data['book']?['list'] ?? res.data['book'] ?? res.data['items'] ?? [];
      setState(() {
        _series = items is List ? items : [];
        _pageInfo = res.data['page_info'];
        _hasMore = _pageInfo?['has_more'] ?? res.data['hasMore'] ?? false;
        _isFeedLoading = false;
      });
    } else {
      if (mounted) setState(() => _isFeedLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isFeedLoading || !_hasMore || _pageInfo == null) return;
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    setState(() => _isFeedLoading = true);

    final res = await ApiService.tabfeed(platformProv.activePlatform, _pageInfo!, lang: platformProv.activeLanguage);
    if (res.success && res.data != null && mounted) {
      final items = res.data['book']?['list'] ?? res.data['book'] ?? res.data['items'] ?? [];
      setState(() {
        _series.addAll(items is List ? items : []);
        _pageInfo = res.data['page_info'];
        _hasMore = _pageInfo?['has_more'] ?? res.data['hasMore'] ?? false;
        _isFeedLoading = false;
      });
    } else {
      if (mounted) setState(() => _isFeedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BROWSE'),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (!_isLoading && _groupedTabs.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.background,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _groupedTabs.entries.map((entry) {
                  final type = entry.key;
                  final items = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            type.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: AppTheme.textSecondary,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 32,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final isActive = _filters[type]?['tab_key'] == item['tab_key'];
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() => _filters[type] = item);
                                    _loadData(); // Ideally should merge all filters into body logically
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: isActive ? AppTheme.textPrimary : Colors.transparent,
                                    foregroundColor: isActive ? AppTheme.background : AppTheme.textSecondary,
                                    side: BorderSide(color: isActive ? AppTheme.textPrimary : AppTheme.border),
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: Text(
                                    item['name'],
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _series.isEmpty && !_isFeedLoading
                    ? const Center(
                        child: Text(
                          'NO SIGNAL. EMPTY FEED.',
                          style: TextStyle(fontFamily: 'monospace', color: AppTheme.textSecondary, letterSpacing: 2),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.surface,
                        onRefresh: _loadData,
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.6,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _series.length + (_isFeedLoading ? 3 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _series.length) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  border: Border.all(color: AppTheme.border),
                                ),
                              );
                            }
                            return SeriesCard(
                              series: _series[i],
                              onTap: () {
                                final platformProv = Provider.of<PlatformProvider>(context, listen: false);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(id: _series[i]['id']?.toString() ?? '', platform: platformProv.activePlatform)));
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
