import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.how_to_vote, size: 80, color: AppTheme.primaryBlue),
            SizedBox(height: 24),
            Text(
              'SecureVote',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.secondaryNavy),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: AppTheme.primaryBlue),
          ],
        ),
      ),
    );
  }
}
