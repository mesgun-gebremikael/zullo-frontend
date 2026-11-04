import '../l10n/localization.dart';
import 'package:flutter/material.dart';

Future<bool> confirmLeaveProfile(BuildContext context) async {
  FocusScope.of(context).unfocus();
  return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: Text(context.l10n.leaveProfileSetup388),
                  content: Text(context
                      .l10n.youWillBeLoggedOutYourAccountAndSavedAnswers),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.l10n.continueAction)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.l10n.leave))
                  ])) ??
      false;
}
