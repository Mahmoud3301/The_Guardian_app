import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? prefillEmail;
  const ResetPasswordPage({super.key, this.prefillEmail});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _loading        = false;

  late final TextEditingController _emailCtrl;
  final _oldCtrl     = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Show centered Done overlay then navigate ───────────────────────────────
  Future<void> _showDoneOverlay() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => const _DoneOverlay(),
    );

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    Navigator.of(context).pop(); // close dialog
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    await AuthService.resetPassword(
      email: _emailCtrl.text,
      oldPassword: _oldCtrl.text,
      newPassword: _newCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    await _showDoneOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BackRow(),
            const SizedBox(height: 40),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // ── Title ─────────────────────────────────
                        const Text(
                          'Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                          ),
                        ),

                        // ── Email ──────────────────────────────────
                        const SizedBox(height: 30),
                        GuardianField(
                          hint: 'Enter Your Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        // ── Old Password ───────────────────────────
                        const SizedBox(height: 16),
                        GuardianField(
                          hint: 'Enter Old Password',
                          controller: _oldCtrl,
                          obscure: _obscureOld,
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _obscureOld = !_obscureOld),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                _obscureOld
                                    ? Icons.remove_red_eye_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF9E9E9E),
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        // ── New Password ───────────────────────────
                        const SizedBox(height: 16),
                        GuardianField(
                          hint: 'Enter New Password',
                          controller: _newCtrl,
                          obscure: _obscureNew,
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _obscureNew = !_obscureNew),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                _obscureNew
                                    ? Icons.remove_red_eye_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF9E9E9E),
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        // ── Confirm New Password ───────────────────
                        const SizedBox(height: 16),
                        GuardianField(
                          hint: 'Confirm New Password',
                          controller: _confirmCtrl,
                          obscure: _obscureConfirm,
                          suffix: GestureDetector(
                            onTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                _obscureConfirm
                                    ? Icons.remove_red_eye_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF9E9E9E),
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        // ── Done button ────────────────────────────
                        const SizedBox(height: 36),
                        DarkBrownButton(
                          label: 'Done',
                          isLoading: _loading,
                          onPressed: _submit,
                        ),

                        // ── Go to Log In ───────────────────────────
                        const SizedBox(height: 14),
                        DarkBrownButton(
                          label: 'Go to Log In page',
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage()),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Centered Done Overlay Widget ──────────────────────────────────────────────
class _DoneOverlay extends StatefulWidget {
  const _DoneOverlay();

  @override
  State<_DoneOverlay> createState() => _DoneOverlayState();
}

class _DoneOverlayState extends State<_DoneOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A2530),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF6B8A9A),
                  size: 52,
                ),
                SizedBox(height: 14),
                Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Password updated!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8899AA),
                    fontWeight: FontWeight.w400,
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