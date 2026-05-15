import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';
import 'create_account_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // ── Title ─────────────────────────────────────────
              const Text(
                'Welcome to the Guardian',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.pureWhite,
                  height: 1.2,
                ),
              ),

              // ── Subtitle ──────────────────────────────────────
              const SizedBox(height: 14),
              const Text(
                'Your home is secured',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pureWhite,
                ),
              ),

              // ── Robot image card ──────────────────────────────
              const SizedBox(height: 22),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/images/robot.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),

              // ── Log In gradient button ────────────────────────
              const SizedBox(height: 24),
              DarkBrownButton(
                label: 'Log In',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                ),
              ),

              // ── Create Account white button ───────────────────
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateAccountPage(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pureWhite,
                    foregroundColor: AppColors.darkText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
