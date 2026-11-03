import 'dart:async';
import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

/// Keeps native notification-channel labels aligned with the displayed language.
///
/// This transparent wrapper only supplies localized labels. The caller retains
/// ownership of channel identity, importance, platform checks and permissions.
class LocalizedNotificationChannel extends StatefulWidget {
  const LocalizedNotificationChannel({
    super.key,
    required this.child,
    required this.onChange,
  });

  final Widget child;
  final Future<void> Function(String name, String description) onChange;

  @override
  State<LocalizedNotificationChannel> createState() =>
      _LocalizedNotificationChannelState();
}

class _LocalizedNotificationChannelState
    extends State<LocalizedNotificationChannel> {
  String? _lastLocale;
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final strings = AppLocalizations.of(context);
    if (strings.localeName == _lastLocale) return;
    _lastLocale = strings.localeName;
    final revision = ++_revision;
    final name = strings.messages;
    final description = strings.chats;
    // A native registration must neither run during build nor delay rendering.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      unawaited(_update(name, description));
    });
  }

  Future<void> _update(String name, String description) async {
    try {
      await widget.onChange(name, description);
    } catch (_) {
      // Channel-label failure must not disrupt chat, startup or locale changes.
      // Never include exception details: platform errors may contain user data.
      debugPrint('Notification channel labels could not be updated.');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
