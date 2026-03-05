import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/app_nav.dart';
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

  List<PersonRecord> get _owners =>
      _store.people.where((p) => p.role == 'Owner').toList();

  List<PersonRecord> get _visitors =>
      _store.people.where((p) => p.role == 'Visitor').toList();

  List<RiskRecord> get _risks => _store.riskPeople;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // ── Title ──────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
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
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [

                  // ── Owners section ─────────────────────────────
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

                  // ── Visitors section ────────────────────────────
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

                  // ── Risk persons section ────────────────────────
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

                  // ── Empty state ─────────────────────────────────
                  if (_owners.isEmpty && _visitors.isEmpty && _risks.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 60),
                        child: Text('No people added yet.',
                            style: TextStyle(color: Colors.white38, fontSize: 16)),
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
            child: Image.asset(
              person.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                isOwner ? Icons.shield_rounded : Icons.person_rounded,
                color: roleColor.withOpacity(0.7),
                size: 28,
              ),
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
            child: Image.asset(
              record.imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person_rounded,
                color: actionColor.withOpacity(0.7),
                size: 28,
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
}