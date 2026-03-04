import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';
import 'home_page.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  bool _obscure  = true;
  bool _loading  = false;

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _nameError     = Validators.fullName(_nameCtrl.text);
      _emailError    = Validators.email(_emailCtrl.text);
      _passwordError = Validators.password(_passwordCtrl.text);
    });
    return _nameError == null && _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);

    final result = await AuthService.register(
      fullName: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      showGuardianSnackBar(
          context, 'Account created! Welcome, ${result.user!.fullName}!');
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
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [

                        // ── Title ─────────────────────────────────
                        const Text(
                          'Create Your Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
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

                        // ── Full Name ──────────────────────────────
                        const SizedBox(height: 30),
                        ValidatedField(
                          hint: 'Enter Full Name',
                          controller: _nameCtrl,
                          keyboardType: TextInputType.name,
                          errorText: _nameError,
                        ),

                        // ── Email ──────────────────────────────────
                        const SizedBox(height: 14),
                        ValidatedField(
                          hint: 'Enter Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          errorText: _emailError,
                        ),

                        // ── Password ───────────────────────────────
                        const SizedBox(height: 14),
                        ValidatedField(
                          hint: 'Enter Password',
                          controller: _passwordCtrl,
                          obscure: _obscure,
                          errorText: _passwordError,
                          suffix: GestureDetector(
                            onTap: () =>
                                setState(() => _obscure = !_obscure),
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

                        // ── Get Started button ─────────────────────
                        const SizedBox(height: 24),
                        DarkBrownButton(
                          label: 'Get Started',
                          isLoading: _loading,
                          onPressed: _submit,
                        ),

                        const SizedBox(height: 26),
                        const LabelDivider(text: 'Sign up with'),
                        const SizedBox(height: 22),
                        const SocialRow(),

                        // ── Log In link ────────────────────────────
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account ? ",
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.subtleWhite),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginPage()),
                              ),
                              child: const Text(
                                'Log In',
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