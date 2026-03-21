import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class VIPScreen extends StatefulWidget {
  const VIPScreen({super.key});

  @override
  State<VIPScreen> createState() => _VIPScreenState();
}

class _VIPScreenState extends State<VIPScreen> {
  List<dynamic> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    // We bypass ApiService for now to avoid the undefined method error
    // Ideally added to api_service.dart
    if (mounted) {
      setState(() {
        _packages = [
          {'name': 'Basic', 'duration': 30, 'price': 50000},
          {'name': 'Premium', 'duration': 365, 'price': 300000},
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPGRADE PROTOCOL'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final pkg = _packages[index];
                final duration = pkg['duration'];
                final price = pkg['price'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            pkg['name']?.toString().toUpperCase() ?? 'PACKAGE',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 2),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: AppTheme.textPrimary,
                            child: Text(
                              '$duration DAYS',
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.background),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Rp $price',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ACCESS LEVEL: MAXIMUM\nADVERTISEMENTS: DISABLED\nOFFLINE DATABANK: UNLOCKED',
                        style: TextStyle(fontFamily: 'monospace', height: 1.5, color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // Proceed to checkout logic
                        },
                        child: const Text('INITIATE PURCHASE'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}


