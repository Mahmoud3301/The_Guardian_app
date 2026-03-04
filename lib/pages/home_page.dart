import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../widgets/shared_widgets.dart';
import 'welcome_page.dart';

class HomePage extends StatelessWidget {
  final UserModel user;
  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Header ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hello 👋',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          color: AppColors.pureWhite,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  // Logout icon
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const WelcomePage()),
                      (route) => false,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.pureWhite,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Status card ─────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E2A35), Color(0xFF0D1520)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: AppColors.pureWhite,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your home is secured',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.pureWhite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Logged in as ${user.email}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.pureWhite.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Info card ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Info',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Name',
                        value: user.fullName),
                    const SizedBox(height: 12),
                    _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email),
                    const SizedBox(height: 12),
                    _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member since',
                        value: user.createdAt),
                  ],
                ),
              ),

              const Spacer(),

              // ── Log Out button ──────────────────────────────────
              DarkBrownButton(
                label: 'Log Out',
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                  (route) => false,
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.pureWhite.withOpacity(0.7)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.pureWhite.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.pureWhite.withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}