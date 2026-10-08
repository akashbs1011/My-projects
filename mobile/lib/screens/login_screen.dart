import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_email.text.trim(), _password.text);
    if (!ok || !mounted) return;

    await context
        .read<LanguageProvider>()
        .adoptUserPreference(auth.user?.preferredLanguage);
    // The router's redirect moves to Home as soon as auth state changes.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: l10n.t('login'),
      subtitle: l10n.t('loginSubtitle'),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.t('noAccount')),
          TextButton(
            onPressed: () => context.push(AppConstants.routeRegister),
            child: Text(l10n.t('register')),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.error != null) ...[
              ErrorView(message: auth.error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _email,
              decoration: InputDecoration(labelText: l10n.t('email')),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: l10n.t('password'),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => Validators.notEmpty(v, 'your password'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: auth.isBusy ? null : _submit,
              child: auth.isBusy
                  ? const ButtonSpinner()
                  : Text(l10n.t('login')),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => context.push(AppConstants.routeForgotPassword),
              child: Text(l10n.t('forgotPassword')),
            ),
          ],
        ),
      ),
    );
  }
}
