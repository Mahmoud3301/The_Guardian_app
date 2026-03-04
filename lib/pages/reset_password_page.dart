import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/validators.dart';
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

  String? _emailError;
  String? _oldError;
  String? _newError;
  String? _confirmError;

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

  bool _validate() {
    setState(() {
      _emailError   = Validators.email(_emailCtrl.text);
      _oldError     = Validators.oldPassword(_oldCtrl.text);
      _newError     = Validators.password(_newCtrl.text);
      _confirmError = Validators.confirmPassword(
          _confirmCtrl.text, _newCtrl.text);
    });
    return _emailError == null &&
        _oldError == null &&
        _newError == null &&
        _confirmError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.resetPassword(
      email: _emailCtrl.text,
      oldPassword: _oldCtrl.text,
      newPassword: _newCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      showGuardianSnackBar(context, 'Password updated successfully!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } else {
      showGuardianSnackBar(context, result.message, isError: true);
    }
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
                        ValidatedField(
                          hint: 'Enter Your Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                        ),

                        // ── Old Password ───────────────────────────
                        const SizedBox(height: 16),
                        ValidatedField(
                          hint: 'Enter Old Password',
                          controller: _oldCtrl,
                          obscure: _obscureOld,
                          errorText: _oldError,
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
                        ValidatedField(
                          hint: 'Enter New Password',
                          controller: _newCtrl,
                          obscure: _obscureNew,
                          errorText: _newError,
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
                        ValidatedField(
                          hint: 'Confirm New Password',
                          controller: _confirmCtrl,
                          obscure: _obscureConfirm,
                          errorText: _confirmError,
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

                        // ── Password hint ──────────────────────────
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text(
                              '• Min 8 chars  • 1 uppercase  • 1 lowercase  • 1 number',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF7A9AAA),
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