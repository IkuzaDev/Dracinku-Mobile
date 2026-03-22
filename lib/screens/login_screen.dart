import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/platform_provider.dart';
//import 'series_detail_screen.dart';
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _licenseController = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  String? _errorMessage;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final key = _licenseController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'License key tidak boleh kosong');
      return;
    }
    setState(() => _errorMessage = null);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final success = await auth.login(key);

    if (success && mounted) {
      await platformProv.fetchPlatforms();
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
    } else if (mounted) {
      setState(() => _errorMessage = 'License key tidak valid atau sudah kadaluarsa');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width > 480 ? (size.width - 440) / 2 : 24,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  _buildHero(context),

                  const SizedBox(height: 48),

                  _buildLicenseField(),

                  const SizedBox(height: 16),

                  _buildLoginButton(auth),

                  const SizedBox(height: 28),

                  _buildDivider(),

                  const SizedBox(height: 28),

                  _buildGoogleButton(),

                  const SizedBox(height: 24),

                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha:0.08), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Image.asset(
              'assets/images/dracinku.ico',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.movie_creation_rounded, color: Colors.white54, size: 32),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'Dracinku',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 8),

        Text(
          'Masukkan license key untuk melanjutkan',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.4),
            fontSize: 13,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLicenseField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LICENSE KEY',
          style: TextStyle(
            color: Colors.white.withValues(alpha:0.4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _errorMessage != null
                  ? Colors.red.withValues(alpha:0.4)
                  : Colors.white.withValues(alpha:0.07),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _licenseController,
            obscureText: _obscure,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
            onSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha:0.2),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
              prefixIcon: Icon(Icons.key_rounded, color: Colors.white.withValues(alpha:0.3), size: 20),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: Colors.white.withValues(alpha:0.3),
                  size: 18,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              border: InputBorder.none,
              filled: false,
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red[400], size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLoginButton(AuthProvider auth) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: auth.isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0A0A0C),
          disabledBackgroundColor: Colors.white.withValues(alpha:0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: auth.isLoading
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0A0C)),
              )
            : const Text(
                'Masuk',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha:0.07))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'atau',
            style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha:0.07))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha:0.1), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFF18181B),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_logo.png', height: 20, width: 20,
              errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.white70),
            ),
            const SizedBox(width: 10),
            Text(
              'Masuk dengan Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha:0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Dengan masuk, kamu menyetujui syarat & ketentuan penggunaan Dracinku.',
      style: TextStyle(color: Colors.white.withValues(alpha:0.2), fontSize: 11, height: 1.5),
      textAlign: TextAlign.center,
    );
  }
}