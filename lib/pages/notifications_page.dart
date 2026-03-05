import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/app_nav.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../widgets/shared_widgets.dart';

// ── Notification entry model ───────────────────────────────────────────────
enum NotifStatus { pending, risk, dismissed }

class _NotifEntry {
  final String id;
  final String imagePath;
  String label;
  NotifStatus status;

  _NotifEntry({
    required this.id,
    required this.imagePath,
    this.label = 'Unknown',
    this.status = NotifStatus.pending,
  });
}

// ── Page ───────────────────────────────────────────────────────────────────
class NotificationsPage extends StatefulWidget {
  final UserModel user;
  const NotificationsPage({super.key, required this.user});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final List<_NotifEntry> _notifications = [
    _NotifEntry(id: '1', imagePath: 'assets/images/unknown1.jpg'),
    _NotifEntry(id: '2', imagePath: 'assets/images/unknown2.jpg'),
    _NotifEntry(id: '3', imagePath: 'assets/images/unknown3.jpg'),
  ];

  OverlayEntry? _overlayEntry;

  void _showToast(String message,
      {IconData icon = Icons.check_circle_rounded,
      Color color = const Color(0xFF4CAF50)}) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) =>
          _ToastOverlay(message: message, icon: icon, color: color),
    );
    Overlay.of(context).insert(_overlayEntry!);
    Future.delayed(const Duration(milliseconds: 2800), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  // ── Yes → naming + role dialog ────────────────────────────────────────
  Future<void> _onYes(_NotifEntry entry) async {
    final ctrl = TextEditingController();
    String selectedRole = 'Visitor'; // default

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => _NamingDialog(
        imagePath: entry.imagePath,
        controller: ctrl,
        initialRole: selectedRole,
        onDone: (name, role) {
          setState(() {
            entry.label  = name.isNotEmpty ? name : 'Unknown';
            entry.status = NotifStatus.dismissed;
          });
          Navigator.pop(ctx);
          _showToast(
            '${name.isNotEmpty ? name : "Person"} added as $role',
            icon: Icons.person_add_rounded,
            color: const Color(0xFF4CAF50),
          );
        },
      ),
    );
    ctrl.dispose();
  }

  void _onNo(_NotifEntry entry) {
    setState(() => entry.status = NotifStatus.risk);
    _showToast(
      'Alert activated! Risk detected.',
      icon: Icons.warning_rounded,
      color: const Color(0xFFFF5722),
    );
  }

  void _onLockDoor(_NotifEntry entry) {
    setState(() => entry.status = NotifStatus.dismissed);
    _showToast('Door locked successfully!',
        icon: Icons.lock_rounded, color: const Color(0xFF2196F3));
  }

  void _onCallEmergency(_NotifEntry entry) {
    setState(() => entry.status = NotifStatus.dismissed);
    _showToast('Emergency services called!',
        icon: Icons.emergency_rounded, color: const Color(0xFFFF1744));
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  List<_NotifEntry> get _visible =>
      _notifications.where((e) => e.status != NotifStatus.dismissed).toList();

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),

            Expanded(
              child: _visible.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        final entry = _visible[i];
                        if (entry.status == NotifStatus.risk) {
                          return _RiskCard(
                            entry: entry,
                            onLockDoor:      () => _onLockDoor(entry),
                            onCallEmergency: () => _onCallEmergency(entry),
                          );
                        }
                        return _PersonCard(
                          entry: entry,
                          onYes: () => _onYes(entry),
                          onNo:  () => _onNo(entry),
                        );
                      },
                    ),
            ),

            AppBottomNav(currentIndex: 2, user: widget.user),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, color: Colors.white24, size: 64),
          SizedBox(height: 16),
          Text('No notifications',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
        ],
      ),
    );
  }
}

// ── Person card ────────────────────────────────────────────────────────────
class _PersonCard extends StatelessWidget {
  final _NotifEntry entry;
  final VoidCallback onYes;
  final VoidCallback onNo;
  const _PersonCard(
      {required this.entry, required this.onYes, required this.onNo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Do you want to add this person?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Center(
              child: _FaceImage(
                  imagePath: entry.imagePath, width: 160, height: 180)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(label: 'Yes', onTap: onYes),
              const SizedBox(width: 16),
              _ActionButton(label: 'No', onTap: onNo),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Risk card ──────────────────────────────────────────────────────────────
class _RiskCard extends StatelessWidget {
  final _NotifEntry entry;
  final VoidCallback onLockDoor;
  final VoidCallback onCallEmergency;

  const _RiskCard({
    required this.entry,
    required this.onLockDoor,
    required this.onCallEmergency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1744).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFF1744).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_rounded,
                        color: Color(0xFFFF5722), size: 16),
                    SizedBox(width: 6),
                    Text('RISK DETECTED',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF5722),
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1820),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFFFF5722).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _FaceImage(
                    imagePath: entry.imagePath, width: 120, height: 130),
                const SizedBox(height: 12),
                const Text('Risk ...',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Alert is working',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RiskButton(
                      label: 'Lock Door',
                      icon: Icons.lock_rounded,
                      color: const Color(0xFF2196F3),
                      onTap: onLockDoor,
                    ),
                    const SizedBox(width: 12),
                    _RiskButton(
                      label: 'Call Emergency',
                      icon: Icons.emergency_rounded,
                      color: const Color(0xFFFF1744),
                      onTap: onCallEmergency,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Face image widget ──────────────────────────────────────────────────────
class _FaceImage extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  const _FaceImage(
      {required this.imagePath, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFF9800), width: 2.5),
            color: Colors.black26,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1C2B38),
              child:
                  const Icon(Icons.person, color: Colors.white38, size: 48),
            ),
          ),
        ),
        Positioned(
          top: 6,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Unknown',
                style: TextStyle(
                    color: Color(0xFFFF9800),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── Naming dialog with Owner / Visitor selector ────────────────────────────
class _NamingDialog extends StatefulWidget {
  final String imagePath;
  final TextEditingController controller;
  final String initialRole;
  final void Function(String name, String role) onDone;

  const _NamingDialog({
    required this.imagePath,
    required this.controller,
    required this.initialRole,
    required this.onDone,
  });

  @override
  State<_NamingDialog> createState() => _NamingDialogState();
}

class _NamingDialogState extends State<_NamingDialog> {
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1820),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text('What is his Name?',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Unknown',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Face
            _FaceImage(
                imagePath: widget.imagePath, width: 130, height: 145),

            const SizedBox(height: 20),

            // Name field
            Container(
              height: 50,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30)),
              child: TextField(
                controller: widget.controller,
                style:
                    const TextStyle(color: Colors.black87, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Name.....',
                  hintStyle:
                      TextStyle(color: Colors.black38, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Role selector ────────────────────────────────────
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Add as:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _RoleOption(
                    label: 'Owner',
                    icon: Icons.shield_rounded,
                    selected: _selectedRole == 'Owner',
                    color: const Color(0xFF6B8A9A),
                    onTap: () => setState(() => _selectedRole = 'Owner'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleOption(
                    label: 'Visitor',
                    icon: Icons.person_outline_rounded,
                    selected: _selectedRole == 'Visitor',
                    color: const Color(0xFFFF9800),
                    onTap: () => setState(() => _selectedRole = 'Visitor'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Done button
            GestureDetector(
              onTap: () => widget.onDone(
                  widget.controller.text.trim(), _selectedRole),
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.btnGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF080820).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role option button ─────────────────────────────────────────────────────
class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.1),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? color : Colors.white38, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? color : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action button (Yes / No) ───────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }
}

// ── Risk action button ─────────────────────────────────────────────────────
class _RiskButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RiskButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Toast overlay ──────────────────────────────────────────────────────────
class _ToastOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  const _ToastOverlay(
      {required this.message, required this.icon, required this.color});

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1820),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: widget.color.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: widget.color.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6)),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.message,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}