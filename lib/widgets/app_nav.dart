import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/livevideo_page.dart';
import 'package:flutter_application_1/pages/notifications_page.dart'; // ← NEW
import '../core/app_colors.dart';
import '../core/user_model.dart';

// Import pages
import '../pages/home_page.dart';
import '../pages/owners_visitors_page.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final UserModel user;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
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
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final selected = currentIndex == i;
          return GestureDetector(
            onTap: () {
              if (i == currentIndex) return; // already on this page

              Widget page;
              switch (i) {
                case 0:
                  page = HomePage(user: user);
                  break;
                case 1:
                  page = LiveVideoPage(user: user);
                  break;
                case 2:                              // ← NOW IMPLEMENTED
                  page = NotificationsPage(user: user);
                  break;
                case 3:
                  page = OwnersVisitorsPage(user: user);
                  break;
                default:
                  return;
              }

              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => page,
                  transitionDuration: const Duration(milliseconds: 200),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
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