import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AuthSplitLayout extends StatelessWidget {
  final Widget child;
  final bool showMobileBranding;
  final VoidCallback? onMobileBackTap;

  const AuthSplitLayout({
    super.key, 
    required this.child,
    this.showMobileBranding = false,
    this.onMobileBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: onMobileBackTap != null
            ? AppBar(
                backgroundColor: AppTheme.backgroundLight,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.secondaryNavy),
                  onPressed: onMobileBackTap,
                ),
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                child,
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 16),
                  child: Text(
                    'Secure voting for organizations',
                    style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Left Side - Premium Gradient Branding
          Expanded(
            flex: 1,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF24324D), // Lighter Slate Navy for high logo visibility
                    Color(0xFF1E293B), // Slate Navy
                    Color(0xFF0F172A), // Deep Slate Navy
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Subtle top-left electric blue ambient glow
                  Positioned(
                    top: -120,
                    left: -120,
                    child: Container(
                      width: 380,
                      height: 380,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                  // Subtle bottom-right gold ambient glow matching logo facets
                  Positioned(
                    bottom: -100,
                    right: -100,
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFC5A059).withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/icon/app_icon_transparent.png',
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'SECUREVOTE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentTeal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, size: 8, color: AppTheme.accentTeal),
                              SizedBox(width: 8),
                              Text(
                                'PRIVACY-AWARE VOTING',
                                style: TextStyle(
                                  color: AppTheme.accentTeal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Secure, private\nvoting for every\norganization.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 48),
                        _buildFeatureItem(
                          icon: Icons.lock_outline,
                          title: 'Server-authorized voting',
                          description: 'Ballots are validated and recorded by trusted backend services.',
                        ),
                        const SizedBox(height: 32),
                        _buildFeatureItem(
                          icon: Icons.fingerprint,
                          title: 'Privacy-aware ballots',
                          description: 'Anonymous ballots are separated from participation records.',
                        ),
                        const SizedBox(height: 32),
                        _buildFeatureItem(
                          icon: Icons.check_circle_outline,
                          title: 'Clear participation receipts',
                          description: 'Voters can confirm participation without revealing their selection.',
                        ),
                        const Spacer(),
                        const Divider(color: Color(0xFF334155)), // Slate 700
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SecureVote',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                            Text(
                              'Android • iOS • Web',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Side - Auth Form
          Expanded(
            flex: 1,
            child: Container(
              color: AppTheme.backgroundLight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
