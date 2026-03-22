import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/platform_provider.dart';
import '../widgets/series_card.dart';
import 'series_detail_screen.dart';

const _bg      = Color(0xFF0A0A0C);
const _surface = Color(0xFF18181B);
const _border  = Color(0xFF27272A);

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl      = TextEditingController();
  final _focus     = FocusNode();
  Timer?  _debounce;

  List<dynamic> _results     = [];
  bool          _isLoading   = false;
  bool          _hasSearched = false;

  static const _suggestions = ['Romance', 'CEO', 'Action', 'Comedy', 'Revenge', 'Fantasy'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlatformProvider>(context, listen: false).addListener(_onPlatformChange);
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    Provider.of<PlatformProvider>(context, listen: false).removeListener(_onPlatformChange);
    super.dispose();
  }

  void _onPlatformChange() {
    if (mounted && _ctrl.text.isNotEmpty) _search(_ctrl.text);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    if (q.length < 2) return;
    final prov = Provider.of<PlatformProvider>(context, listen: false);
    if (mounted) setState(() { _isLoading = true; _hasSearched = true; });

    final res = await ApiService.search(prov.activePlatform, {'keyword': q}, lang: prov.activeLanguage);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final items = res.data['list'] ?? res.data['items'] ?? res.data['book'] ?? [];
      setState(() { _results = items is List ? items : []; _isLoading = false; });
    } else {
      setState(() { _results = []; _isLoading = false; });
    }
  }

  void _clear() {
    _ctrl.clear();
    setState(() { _results = []; _hasSearched = false; });
    _focus.requestFocus();
  }

  void _tap(int i) {
    final prov = Provider.of<PlatformProvider>(context, listen: false);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SeriesDetailScreen(id: _results[i]['id']?.toString() ?? '', platform: prov.activePlatform),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      color: _bg,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _focus.hasFocus ? Colors.white.withValues(alpha:0.2) : _border),
              ),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onChanged: _onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Cari drama, judul, genre…',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.25), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: _ctrl.text.isNotEmpty ? Colors.white.withValues(alpha:0.7) : Colors.white.withValues(alpha:0.25), size: 20),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: _clear,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.1), shape: BoxShape.circle),
                            child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha:0.5), size: 14),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)));
    }

    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
              child: Icon(Icons.search_off_rounded, color: Colors.white.withValues(alpha:0.2), size: 28),
            ),
            const SizedBox(height: 16),
            Text('Tidak ditemukan', style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Coba kata kunci lain', style: TextStyle(color: Colors.white.withValues(alpha:0.2), fontSize: 12)),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildInitialState();
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) => SeriesCard(series: _results[i], onTap: () => _tap(i)),
    );
  }

  Widget _buildInitialState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          // Decorative rings
          SizedBox(
            width: 96, height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 96, height: 96, decoration: BoxDecoration(border: Border.all(color: _border), shape: BoxShape.circle)),
                Container(width: 66, height: 66, decoration: BoxDecoration(border: Border.all(color: _border.withValues(alpha:0.6)), shape: BoxShape.circle)),
                Container(width: 40, height: 40, decoration: BoxDecoration(color: _surface, border: Border.all(color: _border), shape: BoxShape.circle),
                  child: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha:0.3), size: 18)),
                Positioned(top: 8, right: 12, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.15), shape: BoxShape.circle))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Temukan drama favoritmu', style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Ketik minimal 2 karakter untuk mulai', style: TextStyle(color: Colors.white.withValues(alpha:0.2), fontSize: 12)),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions.map((s) => GestureDetector(
              onTap: () { _ctrl.text = s; _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: s.length)); _search(s); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Text(s, style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}