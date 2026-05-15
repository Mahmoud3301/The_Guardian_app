import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/app_nav.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../core/person_store.dart';
import '../widgets/shared_widgets.dart';

class OwnersVisitorsPage extends StatefulWidget {
  final UserModel user;
  const OwnersVisitorsPage({super.key, required this.user});

  @override
  State<OwnersVisitorsPage> createState() => _OwnersVisitorsPageState();
}

class _OwnersVisitorsPageState extends State<OwnersVisitorsPage> {
  final _store = PersonStore.instance;
  bool _syncing = false;

  List<PersonRecord> get _owners =>
      _store.people.where((p) => p.role == 'Owner').toList();

  List<PersonRecord> get _visitors =>
      _store.people.where((p) => p.role == 'Visitor').toList();

  List<RiskRecord> get _risks => _store.riskPeople;

  @override
  void initState() {
    super.initState();
    _syncSupabase();
  }

  Future<void> _syncSupabase() async {
    setState(() => _syncing = true);
    try {
      await _store.syncWithSupabase();
    } catch (_) {}
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _forceRefresh() async {
    setState(() => _syncing = true);
    try {
      await _store.forceRefresh();
    } catch (_) {}
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  const Expanded(
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
                  // Refresh button
                  GestureDetector(
                    onTap: _syncing ? null : _forceRefresh,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _syncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.sync_rounded,
                              color: Colors.white70, size: 22),
                    ),
                  ),
                ],
              ),
            ),

            // Supabase sync status
            if (_syncing)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B8A9A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFF6B8A9A).withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Color(0xFF6B8A9A),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Syncing with Supabase…',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B8A9A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (_owners.isNotEmpty) ...[
                    _sectionHeader(
                      label: 'Owners',
                      icon: Icons.shield_rounded,
                      color: const Color(0xFF6B8A9A),
                    ),
                    const SizedBox(height: 10),
                    ..._owners.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PersonCard(person: p),
                        )),
                  ],

                  if (_visitors.isNotEmpty) ...[
                    if (_owners.isNotEmpty) const SizedBox(height: 6),
                    _sectionHeader(
                      label: 'Visitors',
                      icon: Icons.person_outline_rounded,
                      color: const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 10),
                    ..._visitors.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PersonCard(person: p),
                        )),
                  ],

                  if (_risks.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _sectionHeader(
                      label: 'Risk Persons',
                      icon: Icons.warning_rounded,
                      color: const Color(0xFFFF1744),
                    ),
                    const SizedBox(height: 10),
                    ..._risks.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RiskPersonCard(
                            record: e.value,
                            index: e.key + 1,
                          ),
                        )),
                  ],

                  if (_owners.isEmpty && _visitors.isEmpty && _risks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Text('No people added yet.',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 16)),
                      ),
                    ),
                ],
              ),
            ),

            AppBottomNav(currentIndex: 3, user: widget.user),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
      {required String label, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Person card (Owner / Visitor) ──────────────────────────────────────────
class _PersonCard extends StatelessWidget {
  final PersonRecord person;
  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    final isOwner = person.role == 'Owner';
    final roleColor =
        isOwner ? const Color(0xFF6B8A9A) : const Color(0xFFFF9800);

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
                  color: roleColor.withOpacity(0.4), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildAvatar(person, roleColor, isOwner),
          ),

          const SizedBox(width: 16),

          // Name + Supabase badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.name,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                if (person.networkUrl != null)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2ecc71),
                        ),
                      ),
                      const Text(
                        'Synced',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2ecc71),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Role badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor.withOpacity(0.4)),
            ),
            child: Text(
              person.role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: roleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(PersonRecord person, Color roleColor, bool isOwner) {
    final fallbackIcon = Icon(
      isOwner ? Icons.shield_rounded : Icons.person_rounded,
      color: roleColor.withOpacity(0.7),
      size: 28,
    );

    // Priority: imageBytes > networkUrl > imagePath asset
    if (person.imageBytes != null) {
      return Image.memory(
        person.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallbackIcon,
      );
    }

    if (person.networkUrl != null && person.networkUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: person.networkUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: roleColor.withOpacity(0.5),
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (_, __, ___) {
          // Fall back to local asset
          if (person.imagePath.isNotEmpty) {
            return Image.asset(
              person.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallbackIcon,
            );
          }
          return fallbackIcon;
        },
      );
    }

    if (person.imagePath.isNotEmpty) {
      return Image.asset(
        person.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallbackIcon,
      );
    }

    return fallbackIcon;
  }
}

// ── Risk person card ───────────────────────────────────────────────────────
class _RiskPersonCard extends StatelessWidget {
  final RiskRecord record;
  final int index;
  const _RiskPersonCard({required this.record, required this.index});

  @override
  Widget build(BuildContext context) {
    final isEmergency = record.action == 'Call Emergency';
    final actionColor =
        isEmergency ? const Color(0xFFFF1744) : const Color(0xFF2196F3);
    final actionIcon =
        isEmergency ? Icons.emergency_rounded : Icons.lock_rounded;

    final h = record.time;
    final timeStr =
        '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: actionColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Avatar with red border
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: actionColor.withOpacity(0.6), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildRiskAvatar(record, actionColor),
          ),

          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unknown #$index',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  timeStr,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ),

          // Action badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: actionColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actionIcon, color: actionColor, size: 13),
                const SizedBox(width: 5),
                Text(
                  record.action,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: actionColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAvatar(RiskRecord record, Color actionColor) {
    if (record.imageBytes != null) {
      return Image.memory(
        record.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person_rounded,
          color: actionColor.withOpacity(0.7),
          size: 28,
        ),
      );
    }
    if (record.imagePath.isNotEmpty) {
      return Image.asset(
        record.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person_rounded,
          color: actionColor.withOpacity(0.7),
          size: 28,
        ),
      );
    }
    return Icon(
      Icons.person_rounded,
      color: actionColor.withOpacity(0.7),
      size: 28,
    );
  }
}