import 'l10n/localization.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: LayoutBuilder(builder: (context, box) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight:
                    (box.maxHeight - 48).clamp(0, double.infinity).toDouble()),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F3),
                              borderRadius: BorderRadius.circular(28)),
                          child: const Icon(Icons.favorite_rounded,
                              size: 48, color: Color(0xFFFF4458)))),
                  const SizedBox(height: 28),
                  Text(context.l10n.zullo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF20242C))),
                  const SizedBox(height: 16),
                  Text(
                      context.l10n
                          .meetSomeoneWhoSharesYourCultureYourValuesAndYour,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17, height: 1.5, color: Color(0xFF667085))),
                  const SizedBox(height: 40),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: const Color(0xFF20242C),
                          foregroundColor: Colors.white,
                          elevation: 0),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterPage())),
                      child: Text(context.l10n.createAccount)),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54)),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LoginPage())),
                      child: Text(context.l10n.logIn)),
                ]),
          ),
        );
      })),
    );
  }
}
