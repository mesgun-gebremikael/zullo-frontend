import 'package:flutter/material.dart';

Future<bool> confirmLeaveProfile(BuildContext context) async {
  FocusScope.of(context).unfocus();
  return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('Vill du lämna profilskapandet?'),
                  content: const Text(
                      'Du loggas ut. Ditt konto och redan sparade svar finns kvar så att du kan fortsätta senare.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Fortsätt')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Lämna'))
                  ])) ??
      false;
}
