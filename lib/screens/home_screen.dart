import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/platform_provider.dart';
import '../widgets/series_card.dart';
import '../widgets/platform_switcher.dart';
import '../widgets/language_switcher.dart';
import 'series_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _tabs = [];
  Map<String, dynamic>? _activeTab;
  List<dynamic> _series = [];
  bool _isLoading = true;
  bool _isFeedLoading = false;
  bool _hasMore = true;
  Map<String, dynamic>? _pageInfo;

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlatformProvider>(context, listen: false).addListener(_onPlatformChange);
      _loadTabs();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    Provider.of<PlatformProvider>(context, listen: false).removeListener(_onPlatformChange);
    super.dispose();
  }

  void _onPlatformChange() { if (mounted) _loadTabs(); }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      if (_hasMore && !_isFeedLoading) _loadMore();
    }
  }

  Future<void> _loadTabs() async {
    final prov = Provider.of<PlatformProvider>(context, listen: false);
    if (mounted) setState(() => _isLoading = true);
    final res = await ApiService.tablist(prov.activePlatform, lang: prov.activeLanguage);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _tabs = res.data as List;
        _activeTab = _tabs.isNotEmpty ? _tabs[0] : null;
        _isLoading = false;
      });
      _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    if (_activeTab == null) return;
    final prov = Provider.of<PlatformProvider>(context, listen: false);
    if (mounted) setState(() { _isFeedLoading = true; _series = []; _hasMore = true; });

    final body = {
      'type': _activeTab!['type'],
      'key': _activeTab!['tab_key'],
      'position': _activeTab!['position_index'],
      'page': 1,
    };
    final res = await ApiService.tabdata(prov.activePlatform, body, lang: prov.activeLanguage);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final items = res.data['book']?['list'] ?? res.data['book'] ?? res.data['items'] ?? [];
      setState(() {
        _series = items is List ? items : [];
        _pageInfo = res.data['page_info'] as Map<String, dynamic>?;
        _hasMore = _pageInfo?['has_more'] ?? res.data['isMore'] ?? false;
        _isFeedLoading = false;
      });
    } else {
      setState(() => _isFeedLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isFeedLoading || !_hasMore || _pageInfo == null) return;
    final prov = Provider.of<PlatformProvider>(context, listen: false);
    if (mounted) setState(() => _isFeedLoading = true);

    final res = await ApiService.tabfeed(prov.activePlatform, _pageInfo!, lang: prov.activeLanguage);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final items = res.data['book']?['list'] ?? res.data['book'] ?? res.data['items'] ?? [];
      setState(() {
        _series.addAll(items is List ? items : []);
        _pageInfo = res.data['page_info'] as Map<String, dynamic>?;
        _hasMore = _pageInfo?['has_more'] ?? res.data['isMore'] ?? false;
        _isFeedLoading = false;
      });
    } else {
      setState(() => _isFeedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<PlatformProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(prov, innerBoxIsScrolled),
          if (_tabs.isNotEmpty) _buildTabBar(),
        ],
        body: _buildBody(prov),
      ),
    );
  }

  SliverAppBar _buildAppBar(PlatformProvider prov, bool innerBoxIsScrolled) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF0A0A0C),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      floating: true,
      snap: true,
      pinned: false,
      forceElevated: innerBoxIsScrolled,
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/dracinku.ico',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.movie_rounded, color: Colors.white54, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _PlatformPill(prov: prov, onTap: () => PlatformSwitcher.show(context)),
        ],
      ),
      actions: [
        _LangButton(
          langCode: prov.activeLanguage.substring(0, 2).toUpperCase(),
          onTap: () => LanguageSwitcher.show(context),
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: Colors.white.withValues(alpha:0.06)),
      ),
    );
  }

  SliverPersistentHeader _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        tabs: _tabs,
        activeTab: _activeTab,
        onTabSelected: (t) {
          setState(() => _activeTab = t);
          _loadData();
        },
      ),
    );
  }

  Widget _buildBody(PlatformProvider prov) {
    if (_isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.62,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        itemCount: 12,
        itemBuilder: (_, _) => const _SkeletonCard(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white,
      backgroundColor: const Color(0xFF18181B),
      child: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_series.isEmpty && !_isFeedLoading)
            const SliverFillRemaining(child: _EmptyState()),

          if (_series.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final s = _series[i];
                    return SeriesCard(
                      series: s,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SeriesDetailScreen(
                            id: s['id']?.toString() ?? '',
                            platform: prov.activePlatform,
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _series.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
              ),
            ),

          if (_isFeedLoading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              sliver: const SliverToBoxAdapter(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ),
                ),
              ),
            ),

          if (!_hasMore && _series.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha:0.06))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('End of list', style: TextStyle(color: Colors.white.withValues(alpha:0.2), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ),
                    Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha:0.06))),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _PlatformPill extends StatelessWidget {
  final PlatformProvider prov;
  final VoidCallback onTap;
  const _PlatformPill({required this.prov, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha:0.08), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prov.activePlatformName ?? prov.activePlatform,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha:0.4), size: 16),
          ],
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String langCode;
  final VoidCallback onTap;
  const _LangButton({required this.langCode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha:0.08), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(langCode, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha:0.4), size: 14),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final List<dynamic> tabs;
  final Map<String, dynamic>? activeTab;
  final ValueChanged<Map<String, dynamic>> onTabSelected;

  const _TabBarDelegate({required this.tabs, required this.activeTab, required this.onTabSelected});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 48,
      color: const Color(0xFF0A0A0C),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: tabs.length,
              itemBuilder: (context, i) {
                final t = tabs[i];
                final isActive = activeTab != null &&
                    activeTab!['tab_key'] == t['tab_key'] &&
                    activeTab!['type'] == t['type'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onTabSelected(t as Map<String, dynamic>),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? Colors.white : Colors.white.withValues(alpha:0.08),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        t['name']?.toString() ?? '',
                        style: TextStyle(
                          color: isActive ? const Color(0xFF0A0A0C) : Colors.white.withValues(alpha:0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(height: 0.5, color: Colors.white.withValues(alpha:0.06)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.activeTab != activeTab || old.tabs != tabs;
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Color.lerp(const Color(0xFF18181B), const Color(0xFF27272A), _anim.value),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFF18181B), const Color(0xFF27272A), _anim.value),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            height: 8,
            width: 60,
            decoration: BoxDecoration(
              color: Color.lerp(const Color(0xFF1A1A1D), const Color(0xFF222226), _anim.value),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha:0.07), width: 1),
            ),
            child: Icon(Icons.movie_outlined, color: Colors.white.withValues(alpha:0.2), size: 26),
          ),
          const SizedBox(height: 14),
          Text('Belum ada konten', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Coba ganti tab atau platform', style: TextStyle(color: Colors.white.withValues(alpha:0.15), fontSize: 12)),
        ],
      ),
    );
  }
}