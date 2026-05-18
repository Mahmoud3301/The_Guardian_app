import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_application_1/widgets/app_nav.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../core/person_store.dart';
import '../core/security_event_store.dart';
import '../services/backend_service.dart';
import '../services/supabase_service.dart';
import '../widgets/shared_widgets.dart';

enum NotifStatus { pending, risk, dismissed }

enum NotifFilter { all, pending, risk, dismissed }

class _NotifEntry {
  final String id;
  final String imagePath;
  final Uint8List? imageBytes;
  final Uint8List? faceCropBytes;
  final DateTime createdAt;
  String label;
  NotifStatus status;

  _NotifEntry({
    required this.id,
    required this.imagePath,
    this.imageBytes,
    this.faceCropBytes,
    required this.createdAt,
    this.label = 'Unknown',
    this.status = NotifStatus.pending,
  });
}

class NotificationsPage extends StatefulWidget {
  final UserModel user;
  const NotificationsPage({super.key, required this.user});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  final List<_NotifEntry> _notifications = [];
  NotifFilter _activeFilter = NotifFilter.all;

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _syncFromSecurityEvents();
  }

  void _syncFromSecurityEvents() {
    _notifications.clear();
    for (final e in SecurityEventStore.instance.events) {
      _notifications.add(
        _NotifEntry(
          id: e.id,
          imagePath: e.imagePathFallback,
          imageBytes: e.imageBytes,
          faceCropBytes: e.faceCropBytes,
          createdAt: e.createdAt,
          label: e.label,
          status: e.status == SecurityEventStatus.pending
              ? NotifStatus.pending
              : e.status == SecurityEventStatus.risk
                  ? NotifStatus.risk
                  : NotifStatus.dismissed,
        ),
      );
    }
  }

  void _showToast(String message,
      {IconData icon = Icons.check_circle_rounded,
      Color color = const Color(0xFF4CAF50)}) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (_) => _ToastOverlay(message: message, icon: icon, color: color),
    );
    Overlay.of(context).insert(_overlayEntry!);
    Future.delayed(const Duration(milliseconds: 2800), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Future<void> _onYes(_NotifEntry entry) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => _NamingDialog(
        imagePath: entry.imagePath,
        imageBytes: entry.faceCropBytes ?? entry.imageBytes,
        controller: ctrl,
        initialRole: 'Visitor',
        onDone: (name, role) async {
          final displayName = name.isNotEmpty ? name : 'Unknown';
          final faceBytes = entry.faceCropBytes ?? entry.imageBytes;

          if (faceBytes != null) {
            BackendService.instance.addFace(displayName, faceBytes);
            SupabaseService.instance
                .uploadFacePhoto(displayName, faceBytes)
                .then((url) {
              if (url != null) {
                debugPrint('Face photo uploaded to Supabase: $url');
              }
            });
          }

          final networkUrl =
              SupabaseService.instance.getLatestPhotoUrl(displayName);

          PersonStore.instance.addPerson(
            displayName,
            role,
            entry.imagePath,
            imageBytes: faceBytes,
            networkUrl: networkUrl,
          );
          SecurityEventStore.instance.renameAndDismiss(entry.id, name);
          setState(() {
            entry.label = displayName;
            entry.status = NotifStatus.dismissed;
          });
          Navigator.pop(ctx);
          _showToast(
            '$displayName added as $role',
            icon: Icons.person_add_rounded,
            color: const Color(0xFF4CAF50),
          );
        },
      ),
    );
    ctrl.dispose();
  }

  void _onNo(_NotifEntry entry) {
    SecurityEventStore.instance.markRisk(entry.id);
    setState(() => entry.status = NotifStatus.risk);
    _showToast('Alert activated! Risk detected.',
        icon: Icons.warning_rounded, color: const Color(0xFFFF5722));
  }

  void _onLockDoor(_NotifEntry entry) {
    PersonStore.instance.addRisk(entry.imagePath, 'Lock Door',
        imageBytes: entry.faceCropBytes ?? entry.imageBytes);
    SecurityEventStore.instance.dismiss(entry.id);
    setState(() => entry.status = NotifStatus.dismissed);
    _showToast('Door locked successfully!',
        icon: Icons.lock_rounded, color: const Color(0xFF2196F3));
  }

  void _onCallEmergency(_NotifEntry entry) {
    PersonStore.instance.addRisk(entry.imagePath, 'Call Emergency',
        imageBytes: entry.faceCropBytes ?? entry.imageBytes);
    SecurityEventStore.instance.dismiss(entry.id);
    setState(() => entry.status = NotifStatus.dismissed);
    _showToast('Emergency services called!',
        icon: Icons.emergency_rounded, color: const Color(0xFFFF1744));
  }

  // ── Neglect: dismiss without any label change ────────────────────────────
  void _onNeglect(_NotifEntry entry) {
    SecurityEventStore.instance.neglect(entry.id);
    setState(() => entry.status = NotifStatus.dismissed);
    _showToast('Notification neglected',
        icon: Icons.visibility_off_rounded, color: const Color(0xFF78909C));
  }

  // ── Delete: permanently remove from store ────────────────────────────────
  void _onDelete(_NotifEntry entry) {
    SecurityEventStore.instance.deleteEvent(entry.id);
    setState(() {
      _notifications.removeWhere((e) => e.id == entry.id);
    });
    _showToast('Notification deleted',
        icon: Icons.delete_rounded, color: const Color(0xFFEF5350));
  }

  // ── Delete with confirmation ─────────────────────────────────────────────
  void _confirmDelete(_NotifEntry entry) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => _ConfirmDialog(
        title: 'Delete Notification',
        message: 'Are you sure you want to permanently delete this notification?',
        confirmLabel: 'Delete',
        confirmColor: const Color(0xFFEF5350),
        onConfirm: () {
          Navigator.pop(ctx);
          _onDelete(entry);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Clear all notifications ──────────────────────────────────────────────
  void _confirmClearAll() {
    if (_notifications.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => _ConfirmDialog(
        title: 'Clear All Notifications',
        message:
            'This will permanently remove all ${_notifications.length} notifications. This action cannot be undone.',
        confirmLabel: 'Clear All',
        confirmColor: const Color(0xFFEF5350),
        onConfirm: () {
          Navigator.pop(ctx);
          SecurityEventStore.instance.clearAll();
          setState(() => _notifications.clear());
          _showToast('All notifications cleared',
              icon: Icons.cleaning_services_rounded,
              color: const Color(0xFF78909C));
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  List<_NotifEntry> get _filtered {
    switch (_activeFilter) {
      case NotifFilter.all:
        return _notifications;
      case NotifFilter.pending:
        return _notifications
            .where((e) => e.status == NotifStatus.pending)
            .toList();
      case NotifFilter.risk:
        return _notifications
            .where((e) => e.status == NotifStatus.risk)
            .toList();
      case NotifFilter.dismissed:
        return _notifications
            .where((e) => e.status == NotifStatus.dismissed)
            .toList();
    }
  }

  int _countByStatus(NotifStatus? status) {
    if (status == null) return _notifications.length;
    return _notifications.where((e) => e.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    _syncFromSecurityEvents();
    final items = _filtered;

    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Notifications',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2)),
                  ),
                  if (_notifications.isNotEmpty)
                    GestureDetector(
                      onTap: _confirmClearAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  const Color(0xFFEF5350).withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_sweep_rounded,
                                color: Color(0xFFEF5350), size: 16),
                            SizedBox(width: 4),
                            Text('Clear All',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEF5350))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Filter tabs ─────────────────────────────────────
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(
                    label: 'All',
                    count: _countByStatus(null),
                    selected: _activeFilter == NotifFilter.all,
                    onTap: () =>
                        setState(() => _activeFilter = NotifFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Pending',
                    count: _countByStatus(NotifStatus.pending),
                    selected: _activeFilter == NotifFilter.pending,
                    color: const Color(0xFFFF9800),
                    onTap: () =>
                        setState(() => _activeFilter = NotifFilter.pending),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Risk',
                    count: _countByStatus(NotifStatus.risk),
                    selected: _activeFilter == NotifFilter.risk,
                    color: const Color(0xFFFF5722),
                    onTap: () =>
                        setState(() => _activeFilter = NotifFilter.risk),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Dismissed',
                    count: _countByStatus(NotifStatus.dismissed),
                    selected: _activeFilter == NotifFilter.dismissed,
                    color: const Color(0xFF78909C),
                    onTap: () =>
                        setState(() => _activeFilter = NotifFilter.dismissed),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── List ────────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (_, i) {
                        final entry = items[i];
                        return _SwipeableCard(
                          key: ValueKey(entry.id),
                          onSwipeLeft: () => _confirmDelete(entry),
                          onSwipeRight: () => _onNeglect(entry),
                          child: _buildCard(entry),
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

  Widget _buildCard(_NotifEntry entry) {
    if (entry.status == NotifStatus.risk) {
      return _RiskCard(
        entry: entry,
        onLockDoor: () => _onLockDoor(entry),
        onCallEmergency: () => _onCallEmergency(entry),
        onNeglect: () => _onNeglect(entry),
        onDelete: () => _confirmDelete(entry),
      );
    }
    if (entry.status == NotifStatus.dismissed) {
      return _DismissedCard(
        entry: entry,
        onDelete: () => _confirmDelete(entry),
      );
    }
    return _PersonCard(
      entry: entry,
      onYes: () => _onYes(entry),
      onNo: () => _onNo(entry),
      onNeglect: () => _onNeglect(entry),
      onDelete: () => _confirmDelete(entry),
    );
  }

  Widget _buildEmpty() {
    String message;
    IconData icon;
    switch (_activeFilter) {
      case NotifFilter.pending:
        message = 'No pending notifications';
        icon = Icons.hourglass_empty_rounded;
        break;
      case NotifFilter.risk:
        message = 'No risk alerts';
        icon = Icons.shield_rounded;
        break;
      case NotifFilter.dismissed:
        message = 'No dismissed notifications';
        icon = Icons.check_circle_outline_rounded;
        break;
      default:
        message = 'No notifications';
        icon = Icons.notifications_none_rounded;
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Swipe cards left to delete, right to neglect',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Swipeable card wrapper ─────────────────────────────────────────────────
class _SwipeableCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const _SwipeableCard({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key ?? UniqueKey(),
      background: _swipeBg(
        alignment: Alignment.centerLeft,
        color: const Color(0xFF78909C),
        icon: Icons.visibility_off_rounded,
        label: 'Neglect',
      ),
      secondaryBackground: _swipeBg(
        alignment: Alignment.centerRight,
        color: const Color(0xFFEF5350),
        icon: Icons.delete_rounded,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onSwipeLeft();
        } else {
          onSwipeRight();
        }
        return false; // we handle state ourselves
      },
      child: child,
    );
  }

  Widget _swipeBg({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    this.color = const Color(0xFF6B8A9A),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color.withOpacity(0.6) : Colors.white.withOpacity(0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : Colors.white54)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withOpacity(0.25)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: selected ? color : Colors.white38)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Time-ago helper ────────────────────────────────────────────────────────
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ── Overflow menu (3 dots) ─────────────────────────────────────────────────
class _CardOverflowMenu extends StatelessWidget {
  final VoidCallback onNeglect;
  final VoidCallback onDelete;

  const _CardOverflowMenu({
    required this.onNeglect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
      color: const Color(0xFF1A2A35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      onSelected: (val) {
        if (val == 'neglect') onNeglect();
        if (val == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'neglect',
          child: Row(
            children: [
              Icon(Icons.visibility_off_rounded,
                  color: const Color(0xFF78909C), size: 18),
              const SizedBox(width: 10),
              const Text('Neglect',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded,
                  color: const Color(0xFFEF5350), size: 18),
              const SizedBox(width: 10),
              const Text('Delete',
                  style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Person card (pending) ──────────────────────────────────────────────────
class _PersonCard extends StatelessWidget {
  final _NotifEntry entry;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onNeglect;
  final VoidCallback onDelete;

  const _PersonCard({
    required this.entry,
    required this.onYes,
    required this.onNo,
    required this.onNeglect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with menu
          Row(
            children: [
              const Expanded(
                child: Text('Do you want to add this person?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              _CardOverflowMenu(onNeglect: onNeglect, onDelete: onDelete),
            ],
          ),
          // Timestamp
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 10),
            child: Text(_timeAgo(entry.createdAt),
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500)),
          ),
          Center(
              child: _FaceImage(
                  imagePath: entry.imagePath,
                  imageBytes: entry.faceCropBytes ?? entry.imageBytes,
                  width: 160,
                  height: 180)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                    label: 'Yes',
                    icon: Icons.check_rounded,
                    color: const Color(0xFF4CAF50),
                    onTap: onYes),
                const SizedBox(width: 12),
                _ActionButton(
                    label: 'No',
                    icon: Icons.close_rounded,
                    color: const Color(0xFFFF5722),
                    onTap: onNo),
                const SizedBox(width: 12),
                _ActionButton(
                    label: 'Neglect',
                    icon: Icons.visibility_off_rounded,
                    color: const Color(0xFF78909C),
                    onTap: onNeglect),
              ],
            ),
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
  final VoidCallback onNeglect;
  final VoidCallback onDelete;

  const _RiskCard({
    required this.entry,
    required this.onLockDoor,
    required this.onCallEmergency,
    required this.onNeglect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 18),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Container(
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
              ),
              _CardOverflowMenu(onNeglect: onNeglect, onDelete: onDelete),
            ],
          ),
          // Timestamp
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, top: 4, bottom: 10),
              child: Text(_timeAgo(entry.createdAt),
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w500)),
            ),
          ),
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
                    imagePath: entry.imagePath,
                    imageBytes: entry.faceCropBytes ?? entry.imageBytes,
                    width: 120,
                    height: 130),
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _RiskButton(
                        label: 'Lock Door',
                        icon: Icons.lock_rounded,
                        color: const Color(0xFF2196F3),
                        onTap: onLockDoor),
                    _RiskButton(
                        label: 'Call Emergency',
                        icon: Icons.emergency_rounded,
                        color: const Color(0xFFFF1744),
                        onTap: onCallEmergency),
                    _RiskButton(
                        label: 'Neglect',
                        icon: Icons.visibility_off_rounded,
                        color: const Color(0xFF78909C),
                        onTap: onNeglect),
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

// ── Dismissed card ─────────────────────────────────────────────────────────
class _DismissedCard extends StatelessWidget {
  final _NotifEntry entry;
  final VoidCallback onDelete;

  const _DismissedCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.65,
      child: Container(
        decoration: BoxDecoration(
            gradient: AppColors.cardGradient,
            borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
        child: Row(
          children: [
            // Face thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: entry.faceCropBytes != null || entry.imageBytes != null
                    ? Image.memory(
                        entry.faceCropBytes ?? entry.imageBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1C2B38),
                          child: const Icon(Icons.person,
                              color: Colors.white38, size: 28),
                        ),
                      )
                    : Image.asset(
                        entry.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1C2B38),
                          child: const Icon(Icons.person,
                              color: Colors.white38, size: 28),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF78909C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Dismissed',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF78909C))),
                      ),
                      const SizedBox(width: 8),
                      Text(_timeAgo(entry.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF5350), size: 20),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Face image ─────────────────────────────────────────────────────────────
class _FaceImage extends StatelessWidget {
  final String imagePath;
  final Uint8List? imageBytes;
  final double width;
  final double height;
  const _FaceImage(
      {required this.imagePath,
      this.imageBytes,
      required this.width,
      required this.height});

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageBytes != null
                ? Image.memory(
                    imageBytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1C2B38),
                      child: const Icon(Icons.person,
                          color: Colors.white38, size: 48),
                    ),
                  )
                : Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1C2B38),
                        child: const Icon(Icons.person,
                            color: Colors.white38, size: 48)),
                  ),
          ),
        ),
        Positioned(
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(10)),
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

// ── Naming dialog ──────────────────────────────────────────────────────────
class _NamingDialog extends StatefulWidget {
  final String imagePath;
  final Uint8List? imageBytes;
  final TextEditingController controller;
  final String initialRole;
  final void Function(String name, String role) onDone;
  const _NamingDialog(
      {required this.imagePath,
      this.imageBytes,
      required this.controller,
      required this.initialRole,
      required this.onDone});

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1820),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                _FaceImage(
                    imagePath: widget.imagePath,
                    imageBytes: widget.imageBytes,
                    width: 120,
                    height: 130),
                const SizedBox(height: 16),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30)),
                  child: TextField(
                    controller: widget.controller,
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 15),
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
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Add as:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60)),
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
                      onTap: () =>
                          setState(() => _selectedRole = 'Owner'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _RoleOption(
                      label: 'Visitor',
                      icon: Icons.person_outline_rounded,
                      selected: _selectedRole == 'Visitor',
                      color: const Color(0xFFFF9800),
                      onTap: () =>
                          setState(() => _selectedRole = 'Visitor'),
                    )),
                  ],
                ),
                const SizedBox(height: 20),
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
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _RoleOption(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? color : Colors.white.withOpacity(0.1),
              width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? color : Colors.white38, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? color : Colors.white38)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

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

// ── Confirmation dialog ────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1820),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: confirmColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: confirmColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                    height: 1.4)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: confirmColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: confirmColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(confirmLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
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
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
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
                        shape: BoxShape.circle),
                    child:
                        Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(widget.message,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}