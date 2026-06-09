import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_shell.dart';
import 'onboarding_gender_page.dart';

class OnboardingBirthdatePage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingBirthdatePage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingBirthdatePage> createState() =>
      _OnboardingBirthdatePageState();
}

class _OnboardingBirthdatePageState extends State<OnboardingBirthdatePage> {
  DateTime? _birthDate;

  bool get _canContinue {
    if (_birthDate == null) return false;
    final today = DateTime.now();
    final age = today.year -
        _birthDate!.year -
        ((today.month < _birthDate!.month ||
                (today.month == _birthDate!.month &&
                    today.day < _birthDate!.day))
            ? 1
            : 0);

    return age >= 18;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 24, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );

    if (picked == null) return;

    setState(() {
      _birthDate = picked;
    });
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y / $m / $d';
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      progress: 0.16,
      title: 'När föddes du?',
      subtitle: '',
      canContinue: _canContinue,
      onNext: () {
  widget.data.birthDate = _birthDate;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OnboardingGenderPage(data: widget.data),
    ),
  );
},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                _birthDate == null
                    ? 'Välj födelsedatum'
                    : _formatDate(_birthDate!),
                style: TextStyle(
                  fontSize: 34,
                  letterSpacing: 8,
                  color: _birthDate == null
                      ? const Color(0xFF8E96A3)
                      : const Color(0xFF20242C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Din profil visar din ålder, inte ditt födelsedatum.',
            style: TextStyle(
              fontSize: 22,
              height: 1.25,
              color: Color(0xFF596273),
            ),
          ),
        ],
      ),
    );
  }
}