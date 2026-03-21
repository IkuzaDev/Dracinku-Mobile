import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/platform_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/series_card.dart';
import 'series_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  List<dynamic> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    
    // Listen to platform changes (to redo search or clear results)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final platformProv = Provider.of<PlatformProvider>(context, listen: false);
      platformProv.addListener(_onPlatformChange);
    });
  }

  void _onPlatformChange() {
    if (mounted && _searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final body = {'keyword': query};
    final res = await ApiService.search(platformProv.activePlatform, body, lang: platformProv.activeLanguage);
    
    if (res.success && res.data != null && mounted) {
      final items = res.data['list'] ?? res.data['items'] ?? res.data['book'] ?? [];
      setState(() {
        _results = items is List ? items : [];
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    
    // Remove listener
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    platformProv.removeListener(_onPlatformChange);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SEARCH'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                border: Border.all(color: AppTheme.primary, width: 2), // Utilitarian focus
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'INPUT QUERY...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace'),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _hasSearched && _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        '0 MATCHES FOUND',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                )
              : !_hasSearched
                  ? Center(
                      child: Text(
                        'SYSTEM STANDBY.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.6,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, i) => SeriesCard(
                        series: _results[i],
                        onTap: () {
                          final platformProv = Provider.of<PlatformProvider>(context, listen: false);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(id: _results[i]['id']?.toString() ?? '', platform: platformProv.activePlatform)));
                        },
                      ),
                    ),
    );
  }
}
