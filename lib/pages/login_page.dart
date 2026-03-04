import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import '../widgets/shared_widgets.dart';
import 'create_account_page.dart';
import 'reset_password_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscure  = true;
  bool _remember = false;
  bool _loading  = false;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _emailError    = Validators.email(_emailCtrl.text);
      _passwordError = _passwordCtrl.text.isEmpty ? 'Password is required' : null;
    });
    return _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.login(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      showGuardianSnackBar(context, 'Welcome back, ${result.user!.fullName}!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(user: result.user!)),
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
            const SizedBox(height: 50),

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
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // ── Title ─────────────────────────────────
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Write a personal information',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.subtleWhite,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        // ── Email ──────────────────────────────────
                        const SizedBox(height: 30),
                        ValidatedField(
                          hint: 'Enter Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                        ),

                        // ── Password ───────────────────────────────
                        const SizedBox(height: 14),
                        ValidatedField(
                          hint: 'Password',
                          controller: _passwordCtrl,
                          obscure: _obscure,
                          errorText: _passwordError,
                          suffix: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                _obscure
                                    ? Icons.remove_red_eye_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF9E9E9E),
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        // ── Remember me + Forgot Password ──────────
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _remember = !_remember),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: _remember,
                                      onChanged: (v) =>
                                          setState(() => _remember = v ?? false),
                                      activeColor: const Color(0xFF6B8A9A),
                                      checkColor: AppColors.pureWhite,
                                      side: BorderSide(
                                        color: _remember
                                            ? const Color(0xFF6B8A9A)
                                            : AppColors.subtleWhite,
                                        width: 1.6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Remember me',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.subtleWhite,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ResetPasswordPage()),
                              ),
                              child: const Text(
                                'Forget Password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.subtleWhite,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // ── Log In button ──────────────────────────
                        const SizedBox(height: 26),
                        DarkBrownButton(
                          label: 'Log In',
                          isLoading: _loading,
                          onPressed: _submit,
                        ),

                        const SizedBox(height: 26),
                        const LabelDivider(text: 'Sign in with'),
                        const SizedBox(height: 22),
                        const SocialRow(),

                        // ── Sign Up link ───────────────────────────
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account ? ",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.subtleWhite),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CreateAccountPage()),
                              ),
                              child: const Text(
                                'Sign UP',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
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