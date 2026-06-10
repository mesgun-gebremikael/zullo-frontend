import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_name_page.dart';

class OnboardingStartPage extends StatelessWidget {
  const OnboardingStartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = OnboardingData();

    return OnboardingNamePage(data: data);
  }
}