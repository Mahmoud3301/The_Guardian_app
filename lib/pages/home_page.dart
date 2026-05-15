import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/app_nav.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../services/backend_service.dart';
import '../services/supabase_service.dart';
import '../widgets/shared_widgets.dart';

class HomePage extends StatefulWidget {
  final UserModel user;
  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isArmed = true;
  bool _backendOnline = false;
  bool _checkingStatus = true;
  int _knownFaces = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _checkingStatus = true);
    try {
      _backendOnline = await BackendService.instance.checkHealth();
      _knownFaces = SupabaseService.instance.nameCount;
    } catch (_) {}
    if (mounted) setState(() => _checkingStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                  const SizedBox(height: 10),
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

            // ── Main content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: AppColors.cardGradient,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                  child: Column(
                    children: [
                      _buildToggleSwitch(),
                      const SizedBox(height: 20),
                      _buildStatusCard(),
                      const SizedBox(height: 14),
                      _buildInfoCard(
                          label: 'Battery Health',
                          icon: Icons.battery_full_rounded),
                      const SizedBox(height: 14),
                      _buildInfoCard(
                          label: 'Connection',
                          icon: Icons.wifi_rounded),
                      const SizedBox(height: 14),
                      _buildBackupCard(),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom nav ──────────────────────────────────────────
            AppBottomNav(currentIndex: 0, user: widget.user),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return GestureDetector(
      onTap: () => setState(() => _isArmed = !_isArmed),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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

  /// New: shows backend + Supabase connection status
  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'System Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              GestureDetector(
                onTap: _checkingStatus ? null : _checkStatus,
                child: _checkingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white54, strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: Colors.white54, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Backend status
          _statusRow(
            icon: _backendOnline
                ? Icons.dns_rounded
                : Icons.cloud_off_rounded,
            label: 'Docker Backend',
            value: _backendOnline ? 'Online' : 'Offline',
            color: _backendOnline
                ? const Color(0xFF2ecc71)
                : const Color(0xFFFF5722),
          ),
          const SizedBox(height: 10),

          // Supabase status
          _statusRow(
            icon: Icons.cloud_done_rounded,
            label: 'Supabase Cloud',
            value: SupabaseService.instance.isReady
                ? 'Connected'
                : 'Initializing…',
            color: SupabaseService.instance.isReady
                ? const Color(0xFF2ecc71)
                : const Color(0xFFFF9800),
          ),
          const SizedBox(height: 10),

          // Known faces
          _statusRow(
            icon: Icons.face_rounded,
            label: 'Known Faces',
            value: '$_knownFaces persons',
            color: const Color(0xFF6B8A9A),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String label, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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

  Widget _buildBackupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
          _bullet('9:30'),
          const SizedBox(height: 8),
          _bullet('Updates the Database\nwith New Information'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, right: 10),
          child: Text('•',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w900)),
        ),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 15, color: Colors.white70, height: 1.4)),
        ),
      ],
    );
  }
}