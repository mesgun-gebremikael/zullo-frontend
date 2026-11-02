import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'onboarding_data.dart';
import 'onboarding_name_page.dart';

class OnboardingStartPage extends StatelessWidget {
  final AuthService? authService;
  const OnboardingStartPage({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    final data = OnboardingData();

    return OnboardingNamePage(data: data, authService: authService);
  }
}
