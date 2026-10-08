import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/symptom_provider.dart';
import '../utils/config.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late String _language;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _language = user?.preferredLanguage ?? context.read<LanguageProvider>().code;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await context.read<AuthProvider>().updateProfile(
          name: _name.text.trim(),
          preferredLanguage: _language,
        );
    if (!ok || !mounted) return;

    // Applying the language here keeps the interface and the stored preference
    // in step, and the symptom list is refetched so labels arrive translated.
    await context.read<LanguageProvider>().setLanguage(_language);
    if (!mounted) return;
    await context.read<SymptomProvider>().load(_language, force: true);

    setState(() => _editing = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.t('profileUpdated'))));
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.t('confirmLogout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.alertText),
            child: Text(l10n.t('logout')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    // Clearing the selection prevents one person's symptoms carrying over to
    // whoever signs in next on a shared device.
    context.read<SymptomProvider>().clearSelection();
    await context.read<AuthProvider>().logout();
    // The router redirect sends the person to sign-in as auth state changes.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('profile'))),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingView(rows: 1),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor: AppTheme.clinicalLight,
                        child: Text(
                          user.initial,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.clinicalDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name,
                                style: Theme.of(context).textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(user.email,
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (!_editing)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: l10n.t('editProfile'),
                          onPressed: () => setState(() => _editing = true),
                        ),
                    ],
                  ),

                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    ErrorView(message: auth.error!),
                  ],

                  const SizedBox(height: 18),

                  if (_editing)
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _name,
                            decoration:
                                InputDecoration(labelText: l10n.t('name')),
                            textCapitalization: TextCapitalization.words,
                            validator: Validators.name,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _language,
                            decoration: InputDecoration(
                                labelText: l10n.t('preferredLanguage')),
                            items: [
                              for (final language
                                  in AppLocalizations.supportedLanguages)
                                DropdownMenuItem(
                                  value: language.code,
                                  child: Text(language.nativeName),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _language = value ?? 'en'),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: auth.isBusy ? null : _save,
                                  child: auth.isBusy
                                      ? const ButtonSpinner()
                                      : Text(l10n.t('saveChanges')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    context.read<AuthProvider>().clearError();
                                    setState(() {
                                      _editing = false;
                                      _name.text = user.name;
                                      _language = user.preferredLanguage;
                                    });
                                  },
                                  child: Text(l10n.t('cancel')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        _Row(
                          icon: Icons.person_outline_rounded,
                          label: l10n.t('name'),
                          value: user.name,
                        ),
                        _Row(
                          icon: Icons.mail_outline_rounded,
                          label: l10n.t('email'),
                          value: user.email,
                        ),
                        _Row(
                          icon: Icons.language_rounded,
                          label: l10n.t('preferredLanguage'),
                          value: AppLocalizations.languageFor(
                                  user.preferredLanguage)
                              .nativeName,
                        ),
                        _Row(
                          icon: Icons.event_outlined,
                          label: l10n.t('accountCreated'),
                          value: Formatters.date(user.createdAt),
                          last: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(l10n.t('logout')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.alertText,
              side: const BorderSide(color: AppTheme.alertBorder),
            ),
          ),

          const SizedBox(height: 20),
          Text(
            l10n.t('privacyNote'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Text(
            'v${AppConfig.appVersion}'
            '${AppConfig.isDevelopment ? ' · ${l10n.t('devMode')}' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.line)),
            ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.inkMuted),
          const SizedBox(width: 11),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
