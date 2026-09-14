import 'package:flutter/material.dart';

import 'onboarding_choice_page.dart';
import 'onboarding_data.dart';
import 'onboarding_family_page.dart';
import 'onboarding_shell.dart';

class OnboardingLifestylePage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingLifestylePage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingLifestylePage> createState() =>
      _OnboardingLifestylePageState();
}

class _OnboardingLifestylePageState
    extends State<OnboardingLifestylePage> {
  int _step = 0;

  late int _heightCm;
  late String _workout;
  late String _pets;
  late String _smoking;
  late String _relationshipHistory;
  late String _zodiacSign;

  @override
  void initState() {
    super.initState();

    _heightCm =
    (widget.data.heightCm ?? 0) > 0
        ? widget.data.heightCm!
        : 170;

    _workout = widget.data.workout.isNotEmpty
        ? widget.data.workout
        : 'Ibland';

    _pets =
        widget.data.pets.isNotEmpty ? widget.data.pets : 'Vill inte ha';

    _smoking =
        widget.data.smoking.isNotEmpty ? widget.data.smoking : 'Nej';

    _relationshipHistory =
        widget.data.relationshipHistory.isNotEmpty
            ? widget.data.relationshipHistory
            : 'Varit i ett förhållande';

    _zodiacSign =
        widget.data.zodiacSign.isNotEmpty
            ? widget.data.zodiacSign
            : 'Vattuman';
  }

  void _nextStep() {
    if (_step < 5) {
      setState(() {
        _step++;
      });
      return;
    }

    widget.data.heightCm = _heightCm;
    widget.data.workout = _workout;
    widget.data.pets = _pets;
    widget.data.smoking = _smoking;
    widget.data.relationshipHistory = _relationshipHistory;
    widget.data.zodiacSign = _zodiacSign;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingFamilyPage(
          data: widget.data,
        ),
      ),
    );
  }

  void _previousStep() {
  if (_step > 0) {
    setState(() {
      _step--;
    });
    return;
  }

  Navigator.pop(context);
}

 @override
Widget build(BuildContext context) {
  Widget page;

  switch (_step) {
    case 0:
      page = _buildHeightPage();
      break;

    case 1:
      page = OnboardingChoicePage(
        progress: 0.72,
        title: 'Tränar du?',
        subtitle: 'Välj det alternativ som passar dig bäst.',
        options: const [
          'Aldrig',
          'Ibland',
          'Ofta',
        ],
        selectedValue: _workout,
        onSelected: (value) {
          setState(() {
            _workout = value;
          });
        },
        onNext: _nextStep,
      );
      break;

    case 2:
      page = OnboardingChoicePage(
        progress: 0.75,
        title: 'Har du husdjur?',
        subtitle: 'Berätta lite mer om din livsstil.',
        options: const [
          'Har husdjur',
          'Vill ha husdjur',
          'Vill inte ha',
          'Allergisk',
        ],
        selectedValue: _pets,
        onSelected: (value) {
          setState(() {
            _pets = value;
          });
        },
        onNext: _nextStep,
      );
      break;

    case 3:
      page = OnboardingChoicePage(
        progress: 0.78,
        title: 'Använder du nikotin?',
        subtitle: 'Välj det alternativ som passar dig.',
        options: const [
          'Nej',
          'Ibland',
          'Ja',
        ],
        selectedValue: _smoking,
        onSelected: (value) {
          setState(() {
            _smoking = value;
          });
        },
        onNext: _nextStep,
      );
      break;

    case 4:
      page = OnboardingChoicePage(
        progress: 0.81,
        title: 'Har du varit i en relation?',
        subtitle: 'Välj det som beskriver dig bäst.',
        options: const [
          'Varit i ett förhållande',
          'Inget seriöst',
          'Aldrig haft ett förhållande',
        ],
        selectedValue: _relationshipHistory,
        onSelected: (value) {
          setState(() {
            _relationshipHistory = value;
          });
        },
        onNext: _nextStep,
      );
      break;

    case 5:
    default:
      page = OnboardingChoicePage(
        progress: 0.84,
        title: 'Vad är ditt stjärntecken?',
        subtitle: 'Välj ditt stjärntecken.',
        options: const [
          'Vattuman',
          'Vädur',
          'Kräfta',
          'Stenbock',
          'Tvilling',
          'Lejon',
          'Våg',
          'Fisk',
          'Skytt',
          'Skorpion',
          'Oxe',
          'Jungfru',
        ],
        selectedValue: _zodiacSign,
        onSelected: (value) {
          setState(() {
            _zodiacSign = value;
          });
        },
        onNext: _nextStep,
      );
      break;
  }

  return PopScope(
    canPop: _step == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop) {
        return;
      }

      _previousStep();
    },
    child: page,
  );
}

  Widget _buildHeightPage() {
    return OnboardingShell(
      progress: 0.69,
      title: 'Hur lång är du?',
      subtitle: 'Du kan ändra detta senare i Redigera Info.',
      canContinue: true,
      onNext: _nextStep,
      child: Column(
        children: [
          const Spacer(),

          Text(
            '$_heightCm',
            style: const TextStyle(
              fontSize: 72,
              height: 1,
              fontWeight: FontWeight.w900,
              color: Color(0xFF20242C),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'cm',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 40),

          Slider(
            value: _heightCm.toDouble(),
            min: 140,
            max: 220,
            divisions: 80,
            activeColor: const Color(0xFFE91E63),
            onChanged: (value) {
              setState(() {
                _heightCm = value.round();
              });
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '140 cm',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '220 cm',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}