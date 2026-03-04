import 'package:flutter/material.dart';
import '../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENT BACKGROUND SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────
class GradientScaffold extends StatelessWidget {
  final Widget child;
  const GradientScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHITE ROUNDED TEXT FIELD
// ─────────────────────────────────────────────────────────────────────────────
class GuardianField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final Widget? suffix;

  const GuardianField({
    super.key,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.darkText,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.hintColor,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VALIDATED FIELD
// ─────────────────────────────────────────────────────────────────────────────
class ValidatedField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final TextEditingController controller;
  final Widget? suffix;
  final String? errorText;

  const ValidatedField({
    super.key,
    required this.hint,
    required this.controller,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: errorText != null
                ? Border.all(color: AppColors.error, width: 1.4)
                : null,
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.darkText,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.hintColor,
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              suffixIcon: suffix,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              errorText!,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENT PILL BUTTON  (replaces DarkBrownButton everywhere)
// ─────────────────────────────────────────────────────────────────────────────
class DarkBrownButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const DarkBrownButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: isLoading
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF6B8A9A).withOpacity(0.6),
                    const Color(0xFF080820).withOpacity(0.6),
                  ],
                )
              : AppColors.btnGradient,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF080820).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pureWhite,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHITE PILL BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class WhiteOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const WhiteOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pureWhite,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIVIDER WITH TEXT
// ─────────────────────────────────────────────────────────────────────────────
class LabelDivider extends StatelessWidget {
  final String text;
  const LabelDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: Color(0xFF3A4A55), thickness: 0.8),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF8899AA),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: Color(0xFF3A4A55), thickness: 0.8),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOCIAL ICONS ROW
// ─────────────────────────────────────────────────────────────────────────────
class SocialRow extends StatelessWidget {
  const SocialRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialCircle(
          color: AppColors.facebook,
          child: const Text(
            'f',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
            ),
          ),
        ),
        const SizedBox(width: 28),
        _SocialCircle(
          color: Colors.white,
          child: const Text(
            'G',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4285F4),
            ),
          ),
        ),
        const SizedBox(width: 28),
        _SocialCircle(
          color: Colors.black,
          child: const Icon(Icons.apple, color: Colors.white, size: 26),
        ),
      ],
    );
  }
}

class _SocialCircle extends StatelessWidget {
  final Color color;
  final Widget child;
  const _SocialCircle({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BACK BUTTON ROW
// ─────────────────────────────────────────────────────────────────────────────
class BackRow extends StatelessWidget {
  const BackRow({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.arrow_back_ios, size: 16, color: AppColors.pureWhite),
            SizedBox(width: 4),
            Text(
              'Back',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.pureWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SNACKBAR HELPER
// ─────────────────────────────────────────────────────────────────────────────
void showGuardianSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? AppColors.error : const Color(0xFF2A3F4D),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ),
  );
}