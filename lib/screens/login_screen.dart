import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../router/app_router.dart';

@RoutePage()
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _password = TextEditingController();
  bool _remember = !kIsWeb;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .login(_user.text.trim(), _password.text, remember: _remember && !kIsWeb);
      if (mounted) {
        await continueAfterSession(context.router, ref);
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (_user.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.loginForgotNeedsUser)));
      return;
    }
    try {
      final message = await ref.read(apiProvider).forgotPassword(_user.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(message ?? l10n.loginForgotSent)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset('assets/icon/icon.png', width: 72, height: 72),
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.appTitle, style: theme.textTheme.headlineLarge),
                      Text(l10n.appSubtitle, style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _user,
                        decoration: InputDecoration(labelText: l10n.loginUser),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        validator: (v) => v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: InputDecoration(labelText: l10n.loginPassword),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => v == null || v.isEmpty ? l10n.fieldRequired : null,
                      ),
                      const SizedBox(height: 8),
                      if (kIsWeb)
                        Text(l10n.loginRememberWeb, style: theme.textTheme.bodySmall)
                      else
                        CheckboxListTile(
                          value: _remember,
                          onChanged: (v) => setState(() => _remember = v ?? false),
                          title: Text(l10n.loginRemember),
                          subtitle: Text(l10n.loginRememberHint),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.loginButton),
                      ),
                      TextButton(onPressed: _forgot, child: Text(l10n.loginForgot)),
                      TextButton.icon(
                        onPressed: () => context.router.push(const AboutRoute()),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: Text(l10n.aboutLink),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.disclaimer,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
