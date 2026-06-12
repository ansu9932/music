import 'package:flutter/material.dart';

import '../../core/theme/aura_colors.dart';

/// Minimal centered empty / offline state with a single retry action.
class OfflineState extends StatelessWidget {
  const OfflineState({
    required this.onRetry,
    this.message = 'Nothing to show yet',
    this.icon = Icons.cloud_off_rounded,
    super.key,
  });

  final VoidCallback onRetry;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 44, color: AuraColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AuraColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AuraColors.textPrimary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
