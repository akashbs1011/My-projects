import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/validators.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late String _language;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _language = context.read<LanguageProvider>().code;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final ok = await context.read<AuthProvider>().register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          confirmPassword: _confirm.text,
          preferredLanguage: _language,
        );
    if (!ok || !mounted) return;
    await context.read<LanguageProvider>().setLanguage(_language);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: l10n.t('register'),
      subtitle: l10n.t('registerSubtitle'),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.t('haveAccount')),
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.t('login')),
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
              controller: _name,
              decoration: InputDecoration(labelText: l10n.t('name')),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
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
                helperText: l10n.t('passwordHint'),
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              decoration:
                  InputDecoration(labelText: l10n.t('confirmPassword')),
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  Validators.confirmPassword(v, _password.text),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration:
                  InputDecoration(labelText: l10n.t('preferredLanguage')),
              items: [
                for (final language in AppLocalizations.supportedLanguages)
                  DropdownMenuItem(
                    value: language.code,
                    child: Text(language.nativeName),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _language = value ?? 'en'),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: auth.isBusy ? null : _submit,
              child: auth.isBusy
                  ? const ButtonSpinner()
                  : Text(l10n.t('register')),
            ),
          ],
        ),
      ),
    );
  }
}
