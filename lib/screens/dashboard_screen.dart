import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'vip_screen.dart';
import 'login_screen.dart';

const _bg      = Color(0xFF0A0A0C);
const _surface = Color(0xFF18181B);
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

List<Color> _avatarGrad(String name) =>
    _grads[name.codeUnitAt(0) % _grads.length];

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated || auth.user == null) {
          return Scaffold(
            backgroundColor: _bg,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
                      child: Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha:0.2), size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text('Masuk untuk melanjutkan', style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Akses profil, riwayat, dan fitur lainnya', style: TextStyle(color: Colors.white.withValues(alpha:0.25), fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, foregroundColor: _bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Masuk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final user     = auth.user!;
        final username = user['username']?.toString() ?? 'User';
        final userId   = user['id']?.toString() ?? '';
        final isVip    = auth.isVip;
        final coin     = 0;
        final ticket   = 0;
        final vipExp   = user['vip_expires_at']?.toString();
        final grad     = _avatarGrad(username);

        return Scaffold(
          backgroundColor: _bg,
          body: CustomScrollView(
            slivers: [
              // Hero header
              SliverToBoxAdapter(child: _buildHero(context, auth, username, userId, isVip, grad, vipExp)),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    if (!isVip) ...[
                      _VipBanner(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VIPScreen()))),
                      const SizedBox(height: 16),
                    ],

                    // Stats
                    Row(children: [
                      _StatCard(label: 'Drama', value: '$coin', icon: Icons.monetization_on_rounded, color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      _StatCard(label: 'Episode', value: '$ticket', icon: Icons.confirmation_num_rounded, color: const Color(0xFF8B5CF6)),
                    ]),

                    const SizedBox(height: 20),

                    // Menu
                    _SectionLabel(text: 'Akun'),
                    const SizedBox(height: 10),
                    _MenuRow(icon: Icons.history_rounded,    label: 'Riwayat Tontonan',   onTap: () {}),
                    _MenuRow(icon: Icons.download_rounded,   label: 'Unduhan Saya',        onTap: () {}),
                    const SizedBox(height: 20),
                    _SectionLabel(text: 'Lainnya'),
                    const SizedBox(height: 10),
                    _MenuRow(icon: Icons.settings_rounded,   label: 'Pengaturan',          onTap: () {}),
                    _MenuRow(icon: Icons.help_outline_rounded, label: 'Bantuan',            onTap: () {}),

                    const SizedBox(height: 28),

                    // Sign out
                    GestureDetector(
                      onTap: () => _confirmLogout(context, auth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha:0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.withValues(alpha:0.2)),
                        ),
                        child: Center(child: Text('Keluar', style: TextStyle(color: Colors.red[400], fontSize: 14, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, AuthProvider auth, String username, String userId, bool isVip, List<Color> grad, String? vipExp) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 28),
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: grad.first.withValues(alpha:0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Center(child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text('ID: $userId', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11, fontFamily: 'monospace')),
                const SizedBox(height: 10),
                Row(children: [
                  _RoleBadge(isVip: isVip),
                  if (isVip && vipExp != null) ...[
                    const SizedBox(width: 6),
                    Text('s/d ${_fmtDate(vipExp)}', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 10)),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      return '${d.day} ${_months[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  static const _months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];

  Future<void> _confirmLogout(BuildContext context, AuthProvider auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Keluar?', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Kamu harus login kembali untuk mengakses akun.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 13, height: 1.5)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                    child: const Center(child: Text('Batal', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('Keluar', style: TextStyle(color: _bg, fontSize: 14, fontWeight: FontWeight.w800))),
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) auth.logout();
  }
}

class _RoleBadge extends StatelessWidget {
  final bool isVip;
  const _RoleBadge({required this.isVip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVip ? const Color(0xFF8B5CF6).withValues(alpha:0.15) : Colors.white.withValues(alpha:0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isVip ? const Color(0xFF8B5CF6).withValues(alpha:0.4) : Colors.white.withValues(alpha:0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isVip) ...[Icon(Icons.star_rounded, color: const Color(0xFFA78BFA), size: 12), const SizedBox(width: 4)],
          Text(
            isVip ? 'VIP' : 'Free',
            style: TextStyle(color: isVip ? const Color(0xFFA78BFA) : Colors.white.withValues(alpha:0.4), fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _VipBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _VipBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [const Color(0xFF8B5CF6).withValues(alpha:0.15), const Color(0xFFEC4899).withValues(alpha:0.1)],
          ),
          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha:0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upgrade ke VIP', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Akses semua fitur tanpa batas', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFA78BFA), size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha:0.35), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha:0.45), size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha:0.2), size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha:0.25), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4));
  }
}