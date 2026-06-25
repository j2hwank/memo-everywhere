// Auth screen — optional login/register UI (SPEC-BACKEND-001)
//
// Single screen with a login/register toggle.
// Labels are in Korean per UX requirements.
// On successful login the screen calls Navigator.pop().

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_provider.dart';

/// Login / Register screen.
///
/// The app remains fully functional without login (local Hive storage,
/// offline-first). Logging in enables cloud sync + cloud voice STT.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoginMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isLoginMode) {
      await ref.read(authNotifierProvider.notifier).login(email, password);
    } else {
      await ref.read(authNotifierProvider.notifier).register(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    // On successful login, pop back to the calling page.
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next is AuthLoggedIn) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    final isLoading = authState is AuthLoading;
    final errorMessage =
        authState is AuthError ? (authState).message : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginMode ? '로그인' : '회원가입'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '이메일을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isLoginMode ? '로그인' : '회원가입'),
                ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => setState(
                          () => _isLoginMode = !_isLoginMode,
                        ),
                child: Text(
                  _isLoginMode
                      ? '계정이 없으신가요? 회원가입'
                      : '이미 계정이 있으신가요? 로그인',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
