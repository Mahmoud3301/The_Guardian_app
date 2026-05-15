import 'package:flutter/material.dart';

class AppColors {
  // ── Background ─────────────────────────────────────────────────────────────
  static const Color bgTop    = Color(0xFF1B1B25);
  static const Color bgBottom = Color(0xFF2A3F4D);

  // ── Card (dark style matching screenshot) ───────────────────────────────────
  static const Color cardTop    = Color(0xFF1E2A35);
  static const Color cardBottom = Color(0xFF111820);
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardTop, cardBottom],
  );

  // ── Buttons ─────────────────────────────────────────────────────────────────
  static const Color btnDark  = Color(0xFF425C6D);
  static const Color btnWhite = Color(0xFFFFFFFF);

  // ── Button Gradient (left blue-grey → right deep navy) ───────────────────────
  static const LinearGradient btnGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF6B8A9A), // light blue-grey (left)
      Color(0xFF080820), // deep navy (right)
    ],
  );

  // ── Text Fields ─────────────────────────────────────────────────────────────
  static const Color fieldBg   = Color(0xFFFFFFFF);
  static const Color hintColor = Color(0xFFAFAFAF);

  // ── Typography ──────────────────────────────────────────────────────────────
  static const Color white       = Color(0xFFFFFFFF);
  static const Color subtleWhite = Color(0xFFCCCCCC);
  static const Color gold        = Color(0xFFCCA435);
  static const Color darkText    = Color(0xFF3A2410);

  // ── Pure white ───────────────────────────────────────────────────────────────
  static const Color pureWhite = Color(0xFFFFFFFF);

  // ── Error ────────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFCC3333);

  // ── Social icons ────────────────────────────────────────────────────────────
  static const Color google   = Color(0xFF4285F4);
  static const Color apple    = Color(0xFF000000);

  // ── Background gradient ──────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );
}