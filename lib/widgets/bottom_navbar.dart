import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

const _surface = Color(0xFF111114);
const _border  = Color(0xFF27272A);

const _grads = [
  [Color(0xFFEC4899), Color(0xFFF97316)],
  [Color(0xFF8B5CF6), Color(0xFF6366F1)],
  [Color(0xFF06B6D4), Color(0xFF14B8A6)],
  [Color(0xFFF59E0B), Color(0xFFEAB308)],
  [Color(0xFF10B981), Color(0xFF059669)],
  [Color(0xFFEF4444), Color(0xFFEC4899)],
  [Color(0xFF3B82F6), Color(0xFF06B6D4)],
  [Color(0xFFA855F7), Color(0xFFEC4899)],
];
List<Color> _avatarGrad(String name) => _grads[name.codeUnitAt(0) % _grads.length];

class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavbar({super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.search_rounded,              activeIcon: Icons.search_rounded,              label: 'Cari'),
    _NavItem(icon: Icons.grid_view_rounded,           activeIcon: Icons.grid_view_rounded,           label: 'Jelajah'),
    _NavItem(icon: Icons.home_rounded,                activeIcon: Icons.home_rounded,                label: 'Beranda', isFab: true),
    _NavItem(icon: Icons.download_rounded,            activeIcon: Icons.download_rounded,            label: 'Unduhan'),
    _NavItem(icon: Icons.person_outline_rounded,      activeIcon: Icons.person_rounded,              label: 'Profil',  isProfile: true),
  ];

  @override
  Widget build(BuildContext context) {
    final auth   = Provider.of<AuthProvider>(context, listen: false);
    final user   = auth.user;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _border, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.5), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item     = _items[i];
              final isActive = i == currentIndex;

              if (item.isFab) return _FabItem(isActive: isActive, onTap: () => onTap(i));

              if (item.isProfile && user != null) {
                final username = user['username']?.toString() ?? 'U';
                final grad     = _avatarGrad(username);
                return _ProfileItem(
                  username: username,
                  grad: grad,
                  isActive: isActive,
                  label: item.label,
                  onTap: () => onTap(i),
                );
              }

              return _DefaultItem(item: item, isActive: isActive, onTap: () => onTap(i));
            }),
          ),
        ),
      ),
    );
  }
}

// ── Nav item data ─────────────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final bool     isFab;
  final bool     isProfile;
  const _NavItem({required this.icon, required this.activeIcon, required this.label, this.isFab = false, this.isProfile = false});
}

// ── Default tab item ──────────────────────────────────────────────────────────
class _DefaultItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  const _DefaultItem({required this.item, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha:0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? Colors.white : Colors.white.withValues(alpha:0.3),
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withValues(alpha:0.3),
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB (Home) center item ────────────────────────────────────────────────────
class _FabItem extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  const _FabItem({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: 46,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isActive ? Colors.white : Colors.white.withValues(alpha:0.12), width: 1),
                boxShadow: isActive ? [BoxShadow(color: Colors.white.withValues(alpha:0.15), blurRadius: 12, offset: const Offset(0, 2))] : [],
              ),
              child: Icon(
                Icons.home_rounded,
                color: isActive ? const Color(0xFF0A0A0C) : Colors.white.withValues(alpha:0.4),
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Beranda',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withValues(alpha:0.3),
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile tab item (avatar when logged in) ──────────────────────────────────
class _ProfileItem extends StatelessWidget {
  final String username;
  final List<Color> grad;
  final bool isActive;
  final String label;
  final VoidCallback onTap;
  const _ProfileItem({required this.username, required this.grad, required this.isActive, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: 1.5),
              ),
              child: Center(
                child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withValues(alpha:0.3),
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}