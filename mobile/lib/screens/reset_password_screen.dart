import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'auth_scaffold.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.token});

  final String? token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _token;
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.token ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final ok = await context.read<AuthProvider>().resetPassword(
          token: _token.text.trim(),
          password: _password.text,
          confirmPassword: _confirm.text,
        );
    if (!ok || !mounted) return;

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.t('passwordResetDone'))),
    );
    router.go(AppConstants.routeLogin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    return AuthScaffold(
      title: l10n.t('resetPassword'),
      subtitle: l10n.t('resetPasswordSubtitle'),
      footer: TextButton(
        onPressed: () => context.go(AppConstants.routeLogin),
        child: Text(l10n.t('login')),
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
            if (widget.token == null) ...[
              TextFormField(
                controller: _token,
                decoration: InputDecoration(labelText: l10n.t('resetToken')),
                validator: (v) => Validators.notEmpty(v, 'the reset token'),
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: l10n.t('newPassword'),
                helperText: l10n.t('passwordHint'),
                helperMaxLines: 2,
              ),
              obscureText: true,
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              decoration:
                  InputDecoration(labelText: l10n.t('confirmPassword')),
              obscureText: true,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => Validators.confirmPassword(v, _password.text),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: auth.isBusy ? null : _submit,
              child: auth.isBusy
                  ? const ButtonSpinner()
                  : Text(l10n.t('resetPassword')),
            ),
          ],
        ),
      ),
    );
  }
}
