import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../utils/config.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  Map<String, dynamic>? _response;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final response =
        await context.read<AuthProvider>().forgotPassword(_email.text.trim());
    if (mounted && response != null) setState(() => _response = response);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();

    if (_response != null) {
      // Present only when the backend runs with DEBUG=true, so the reset flow
      // can be completed locally without an email provider configured.
      final debugToken = _response!['debug_reset_token'] as String?;

      return AuthScaffold(
        title: l10n.t('resetPassword'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_read_outlined,
                size: 42, color: AppTheme.clinical),
            const SizedBox(height: 16),
            Text(
              _response!['message'] as String? ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (debugToken != null && AppConfig.isDevelopment) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cautionBg,
                  border: Border.all(color: AppTheme.cautionBorder),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('devMode').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.cautionText,
                          letterSpacing: 0.6,
                        )),
                    const SizedBox(height: 6),
                    SelectableText(
                      debugToken,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        color: AppTheme.cautionText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push(
                        '${AppConstants.routeResetPassword}?token=$debugToken',
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        foregroundColor: AppTheme.cautionText,
                      ),
                      child: const Text('Continue to reset'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.go(AppConstants.routeLogin),
              child: Text(l10n.t('login')),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: l10n.t('forgotPassword'),
      subtitle: l10n.t('forgotPasswordSubtitle'),
      footer: TextButton(
        onPressed: () => context.pop(),
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
            TextFormField(
              controller: _email,
              decoration: InputDecoration(labelText: l10n.t('email')),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: Validators.email,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: auth.isBusy ? null : _submit,
              child: auth.isBusy
                  ? const ButtonSpinner()
                  : Text(l10n.t('sendResetLink')),
            ),
          ],
        ),
      ),
    );
  }
}
