import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../widgets/shared_widgets.dart';

class HomePage extends StatefulWidget {
  final UserModel user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isArmed = true;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'The Guardian',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Main scrollable content ─────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF131E28),
                    borderRadius: BorderRadius.circular(36),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  child: Column(
                    children: [

                      // ── Toggle switch ──────────────────────────
                      _buildToggleSwitch(),
                      const SizedBox(height: 20),

                      // ── Battery Health ─────────────────────────
                      _buildInfoCard(
                        label: 'Battery Health',
                        icon: Icons.battery_full_rounded,
                      ),
                      const SizedBox(height: 14),

                      // ── Connection ─────────────────────────────
                      _buildInfoCard(
                        label: 'Connection',
                        icon: Icons.wifi_rounded,
                      ),
                      const SizedBox(height: 14),

                      // ── Backup Time ────────────────────────────
                      _buildBackupCard(),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom nav bar ──────────────────────────────────────
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Toggle Switch ──────────────────────────────────────────────────────────
  Widget _buildToggleSwitch() {
    return GestureDetector(
      onTap: () => setState(() => _isArmed = !_isArmed),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2B38),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 64,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: _isArmed
                  ? const LinearGradient(
                      colors: [Color(0xFF6B8A9A), Color(0xFF2A3F50)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: _isArmed ? null : const Color(0xFF2E3E4A),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment:
                  _isArmed ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(4),
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Info Card ──────────────────────────────────────────────────────────────
  Widget _buildInfoCard({required String label, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2B38),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          Icon(icon, color: Colors.white, size: 30),
        ],
      ),
    );
  }

  // ── Backup Time Card ───────────────────────────────────────────────────────
  Widget _buildBackupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2B38),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Backup Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildBulletRow('9:30'),
          const SizedBox(height: 8),
          _buildBulletRow('Updates the  Database\nwith New Informtion'),
        ],
      ),
    );
  }

  Widget _buildBulletRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, right: 10),
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom Navigation Bar ──────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      Icons.home_rounded,
      Icons.sensors_rounded,
      Icons.notifications_rounded,
      Icons.group_rounded,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131E28),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = _selectedIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? const Color(0xFF2E4255)
                    : const Color(0xFF1C2B38),
              ),
              child: Icon(
                items[i],
                color: selected ? Colors.white : Colors.white54,
                size: 26,
              ),
            ),
          );
        }),
      ),
    );
  }
}