import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'onboarding_location_page.dart';
import 'onboarding_shell.dart';

class OnboardingWorkPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingWorkPage({super.key, required this.data});

  @override
  State<OnboardingWorkPage> createState() => _OnboardingWorkPageState();
}

class _OnboardingWorkPageState extends State<OnboardingWorkPage> {
  final _studyPlace = TextEditingController();
  final _studySubject = TextEditingController();
  final _workPlace = TextEditingController();
  final _jobTitle = TextEditingController();

  String _workStatus = 'study';

  @override
  Widget build(BuildContext context) {
    final isStudy = _workStatus == 'study';

    return OnboardingShell(
      progress: 0.58,
      title: 'Vad jobbar du med?',
      subtitle: 'Välj om du pluggar eller jobbar just nu.',
      canContinue: true,
      onNext: () {
        widget.data.workStatus = _workStatus;
        widget.data.studyPlace = _studyPlace.text.trim();
        widget.data.studySubject = _studySubject.text.trim();
        widget.data.workPlace = _workPlace.text.trim();
        widget.data.jobTitle = _jobTitle.text.trim();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingLocationPage(data: widget.data),
          ),
        );
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              _chip('Pluggar just nu', 'study'),
              const SizedBox(width: 10),
              _chip('Jobbar just nu', 'work'),
            ],
          ),
          const SizedBox(height: 26),
          if (isStudy) ...[
            _field(_studyPlace, 'Var pluggar du?', 'Stockholm, universitet, skola...'),
            const SizedBox(height: 18),
            _field(_studySubject, 'Vad pluggar du?', 'Data, ekonomi, vård...'),
          ] else ...[
            _field(_workPlace, 'Var jobbar du?', 'Företag, plats, bransch...'),
            const SizedBox(height: 18),
            _field(_jobTitle, 'Vad har du för jobbtitel?', 'Utvecklare, lärare, chaufför...'),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _workStatus == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFE91E63),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF20242C),
        fontWeight: FontWeight.w800,
      ),
      onSelected: (_) => setState(() => _workStatus = value),
    );
  }

  Widget _field(TextEditingController controller, String title, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}