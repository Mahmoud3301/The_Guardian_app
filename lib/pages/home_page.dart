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
  bool _serverOn = false;
  bool _cameraOn = false;
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
      _serverOn = _backendOnline;
      _knownFaces = SupabaseService.instance.nameCount;
    } catch (_) {}
    if (mounted) setState(() => _checkingStatus = false);
  }

  Future<void> _toggleServer(bool value) async {
    setState(() => _serverOn = value);
    if (value) {
      // Try to connect to backend
      final online = await BackendService.instance.checkHealth();
      if (mounted) {
        setState(() {
          _backendOnline = online;
          _serverOn = online;
        });
        if (!online) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠ Server not found. Make sure docker-compose is running.',
              ),
              backgroundColor: const Color(0xFFFF5722),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } else {
      setState(() => _backendOnline = false);
    }
  }

  void _toggleCamera(bool value) {
    setState(() => _cameraOn = value);
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
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B8A9A).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/robot.png',
                        fit: BoxFit.contain,
                      ),
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
                      // ── Server ON/OFF ──────────────────────────
                      _buildControlToggle(
                        label: 'Server',
                        icon: Icons.dns_rounded,
                        isOn: _serverOn,
                        onChanged: _toggleServer,
                        statusText: _serverOn ? 'Online' : 'Offline',
                        statusColor: _serverOn
                            ? const Color(0xFF2ecc71)
                            : const Color(0xFFFF5722),
                      ),
                      const SizedBox(height: 14),
                      // ── Camera ON/OFF ──────────────────────────
                      _buildControlToggle(
                        label: 'Camera',
                        icon: Icons.videocam_rounded,
                        isOn: _cameraOn,
                        onChanged: (v) => _toggleCamera(v),
                        statusText: _cameraOn ? 'Active' : 'Off',
                        statusColor: _cameraOn
                            ? const Color(0xFF2ecc71)
                            : const Color(0xFFFF5722),
                      ),
                      const SizedBox(height: 20),
                      _buildStatusCard(),
                      const SizedBox(height: 14),
                      _buildInfoCard(
                        label: 'Battery Health',
                        icon: Icons.battery_full_rounded,
                      ),
                      const SizedBox(height: 14),
                      _buildInfoCard(
                        label: 'Connection',
                        icon: Icons.wifi_rounded,
                      ),
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

  /// ON/OFF control toggle for Server / Camera
  Widget _buildControlToggle({
    required String label,
    required IconData icon,
    required bool isOn,
    required ValueChanged<bool> onChanged,
    required String statusText,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOn
              ? const Color(0xFF2ecc71).withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          // Label + Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          // Toggle switch
          GestureDetector(
            onTap: () => onChanged(!isOn),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: isOn
                    ? const LinearGradient(
                        colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
                      )
                    : null,
                color: isOn ? null : const Color(0xFF2E3E4A),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
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
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white54,
                        size: 22,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Backend status
          _statusRow(
            icon: _backendOnline ? Icons.dns_rounded : Icons.cloud_off_rounded,
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
}
