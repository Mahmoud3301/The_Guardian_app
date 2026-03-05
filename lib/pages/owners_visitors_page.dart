import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/app_nav.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../widgets/shared_widgets.dart';

class OwnersVisitorsPage extends StatelessWidget {
  final UserModel user;
  const OwnersVisitorsPage({super.key, required this.user});

  static const List<_PersonEntry> _people = [
    _PersonEntry(name: 'Mahmoud', role: 'Owner'),
    _PersonEntry(name: 'Mohab',   role: 'Owner'),
    _PersonEntry(name: 'Mina',    role: 'Owner'),
    _PersonEntry(name: 'Ali',     role: 'Owner'),
    _PersonEntry(name: 'Amr',     role: 'Visitors'),
    _PersonEntry(name: 'Nabil',   role: 'Visitors'),
  ];

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // ── Title ──────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Text(
                'Owners & Visitors',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            // ── List ───────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _people.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildCard(_people[i]),
              ),
            ),

            // ── Bottom nav ─────────────────────────────────────────
            AppBottomNav(currentIndex: 3, user: user),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_PersonEntry person) {
    final isOwner = person.role == 'Owner';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(
                  color: Colors.white.withOpacity(0.15), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/person1.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: Colors.white54,
                  size: 30),
            ),
          ),
          const SizedBox(width: 16),
          // Name
          Expanded(
            child: Text(
              person.name,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          // Role badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              person.role,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isOwner ? Colors.white : Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonEntry {
  final String name;
  final String role;
  const _PersonEntry({required this.name, required this.role});
}