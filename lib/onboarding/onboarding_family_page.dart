import 'package:flutter/material.dart';

import 'onboarding_bio_page.dart';
import 'onboarding_choice_page.dart';
import 'onboarding_data.dart';

class OnboardingFamilyPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingFamilyPage({
    super.key,
    required this.data,
  });

  @override
  State<OnboardingFamilyPage> createState() =>
      _OnboardingFamilyPageState();
}

class _OnboardingFamilyPageState extends State<OnboardingFamilyPage> {
  int _step = 0;

  late String _childrenCount;
  late String _wantChildren;

  @override
  void initState() {
    super.initState();

    _childrenCount = widget.data.childrenCount.isNotEmpty
        ? widget.data.childrenCount
        : 'Jag har inga barn';

    _wantChildren = widget.data.wantChildren.isNotEmpty
        ? widget.data.wantChildren
        : 'Inte säker än';
  }

  void _nextStep() {
    if (_step == 0) {
      setState(() {
        _step = 1;
      });
      return;
    }

    widget.data.childrenCount = _childrenCount;
    widget.data.wantChildren = _wantChildren;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingBioPage(
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

  if (_step == 0) {
    page = OnboardingChoicePage(
      progress: 0.87,
      title: 'Hur många barn har du?',
      subtitle: 'Detta hjälper dig hitta personer som passar dig.',
      options: const [
        'Jag har inga barn',
        '1 barn',
        '2 barn',
        '3 barn',
        '4 eller fler',
      ],
      selectedValue: _childrenCount,
      onSelected: (value) {
        setState(() {
          _childrenCount = value;
        });
      },
      onNext: _nextStep,
    );
  } else {
    page = OnboardingChoicePage(
      progress: 0.90,
      title: 'Vill du ha barn i framtiden?',
      subtitle: 'Välj det alternativ som passar dig bäst.',
      options: const [
        'Jag vill ha barn',
        'Inte säker än',
        'Jag vill inte ha barn',
      ],
      selectedValue: _wantChildren,
      onSelected: (value) {
        setState(() {
          _wantChildren = value;
        });
      },
      onNext: _nextStep,
    );
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
}