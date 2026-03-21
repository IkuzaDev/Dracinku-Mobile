import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CardSkeleton extends StatelessWidget {
  final int count;

  const CardSkeleton({super.key, this.count = 12});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Icon(Icons.image, color: AppTheme.border, size: 32),
          ),
        );
      },
    );
  }
}

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.primary,
        strokeWidth: 3,
      ),
    );
  }
}
