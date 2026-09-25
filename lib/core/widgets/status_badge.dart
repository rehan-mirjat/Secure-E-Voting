import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeType { status, privacy, role }

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusBadge.eventStatus(String status) {
    final cleanStatus = status.trim().toUpperCase();
    switch (cleanStatus) {
      case 'ACTIVE':
        return StatusBadge(
          label: 'ACTIVE',
          backgroundColor: AppTheme.success.withValues(alpha: 0.12),
          textColor: AppTheme.success,
          icon: Icons.play_circle_fill_rounded,
        );
      case 'SCHEDULED':
        return StatusBadge(
          label: 'SCHEDULED',
          backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
          textColor: AppTheme.primaryBlue,
          icon: Icons.event_rounded,
        );
      case 'CLOSED':
        return StatusBadge(
          label: 'CLOSED',
          backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.12),
          textColor: AppTheme.textSecondary,
          icon: Icons.lock_clock_rounded,
        );
      case 'CANCELLED':
        return StatusBadge(
          label: 'CANCELLED',
          backgroundColor: AppTheme.error.withValues(alpha: 0.12),
          textColor: AppTheme.error,
          icon: Icons.cancel_rounded,
        );
      case 'DRAFT':
      default:
        return StatusBadge(
          label: 'DRAFT',
          backgroundColor: AppTheme.warning.withValues(alpha: 0.12),
          textColor: AppTheme.warning,
          icon: Icons.edit_note_rounded,
        );
    }
  }

  factory StatusBadge.privacyMode(String privacyMode) {
    final cleanMode = privacyMode.trim().toUpperCase();
    if (cleanMode == 'IDENTIFIABLE') {
      return StatusBadge(
        label: 'IDENTIFIABLE',
        backgroundColor: Colors.deepOrange.withValues(alpha: 0.12),
        textColor: Colors.deepOrange.shade800,
        icon: Icons.account_circle_rounded,
      );
    }
    return StatusBadge(
      label: 'ANONYMOUS',
      backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.12),
      textColor: AppTheme.accentTeal,
      icon: Icons.visibility_off_rounded,
    );
  }

  factory StatusBadge.role(String role) {
    final cleanRole = role.trim().toLowerCase();
    if (cleanRole == 'owner') {
      return StatusBadge(
        label: 'OWNER',
        backgroundColor: Colors.purple.withValues(alpha: 0.12),
        textColor: Colors.purple.shade700,
        icon: Icons.stars_rounded,
      );
    } else if (cleanRole == 'admin') {
      return StatusBadge(
        label: 'ADMIN',
        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.12),
        textColor: AppTheme.primaryBlue,
        icon: Icons.admin_panel_settings_rounded,
      );
    }
    return StatusBadge(
      label: 'MEMBER',
      backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.12),
      textColor: AppTheme.textSecondary,
      icon: Icons.person_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
