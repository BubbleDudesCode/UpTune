import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:Bloomee/theme_data/default.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'ls.bloomee.musicplayer://login-callback',
        scopes: 'email profile',
      );
      // Supabase will bring the app back via deep link; session will be set.
      // GoRouter redirect will handle navigation (including ProfileSetup enforcement).
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Google sign-in failed.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        // Decide destination based on profile existence
        try {
          final user = supabase.auth.currentUser;
          if (user != null) {
            final res = await supabase
                .from('profiles')
                .select('id')
                .eq('id', user.id)
                .maybeSingle();
            if (mounted) {
              if (res == null) {
                context.go('/ProfileSetup');
              } else {
                context.go('/Explore');
              }
            }
          } else {
            if (mounted) context.go('/Explore');
          }
        } catch (_) {
          if (mounted) context.go('/Explore');
        }
      } else {
        final res = await supabase.auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (supabase.auth.currentSession != null || res.session != null) {
          if (mounted) context.go('/ProfileSetup');
        } else {
          _showSnack('Check your email to confirm the account, then sign in to continue with profile setup.');
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (e) {
      if (mounted) _showSnack('Unexpected error, please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: Default_Theme.secondoryTextStyle,
        ),
        backgroundColor: Default_Theme.accentColor2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Default_Theme.themeColor,
      appBar: AppBar(
        backgroundColor: Default_Theme.themeColor,
        title: Text(
          _isLogin ? 'Sign In' : 'Create Account',
          style: Default_Theme.primaryTextStyle.merge(
            const TextStyle(color: Default_Theme.primaryColor1),
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Default_Theme.themeColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome to UpTune',
                      style: Default_Theme.primaryTextStyle.merge(
                        const TextStyle(
                          color: Default_Theme.primaryColor1,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isLogin ? 'Sign in to continue' : 'Register to get started',
                      style: Default_Theme.secondoryTextStyle.merge(
                        TextStyle(
                          color: Default_Theme.primaryColor1.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: Default_Theme.secondoryTextStyle.merge(
                        const TextStyle(color: Default_Theme.primaryColor1),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: Default_Theme.secondoryTextStyle,
                        filled: true,
                        fillColor: Default_Theme.themeColor.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.primaryColor2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.primaryColor2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.accentColor2, width: 2),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      style: Default_Theme.secondoryTextStyle.merge(
                        const TextStyle(color: Default_Theme.primaryColor1),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: Default_Theme.secondoryTextStyle,
                        filled: true,
                        fillColor: Default_Theme.themeColor.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.primaryColor2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.primaryColor2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Default_Theme.accentColor2, width: 2),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Default_Theme.accentColor2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                  valueColor: AlwaysStoppedAnimation<Color>(Default_Theme.primaryColor2),
                                ),
                              )
                            : Text(
                                _isLogin ? 'Sign In' : 'Register',
                                style: Default_Theme.primaryTextStyle.merge(
                                  const TextStyle(
                                    color: Default_Theme.primaryColor2,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Default_Theme.themeColor.withOpacity(0.25),
                          side: BorderSide(color: Default_Theme.primaryColor2.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: _loading ? null : _signInWithGoogle,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Brand(
                                Brands.google,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Google',
                              style: Default_Theme.primaryTextStyle.merge(
                                const TextStyle(
                                  color: Default_Theme.primaryColor1,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Create one"
                            : 'Already have an account? Sign in',
                        style: Default_Theme.secondoryTextStyle.merge(
                          const TextStyle(color: Default_Theme.primaryColor1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
