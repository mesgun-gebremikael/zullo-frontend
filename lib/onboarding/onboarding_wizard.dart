import '../l10n/localization.dart';
import '../widgets/conversation_prompt_editor.dart';
import '../splash_page.dart';
import 'package:flutter/services.dart';
import 'confirm_leave.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../main_navigation.dart';
import '../welcome_page.dart';
import '../services/account_session.dart';
import '../services/auth_service.dart';
import '../services/photo_service.dart';
import 'onboarding_data.dart';
import 'onboarding_steps.dart';
import 'profile_setup_controller.dart';

/// One navigation state and one data model. Views never own a second copy of
/// an answer; moving back, resuming and autosave all use the same values.
class OnboardingWizard extends StatefulWidget {
  final OnboardingData? data;
  final OnboardingStep initialStep;
  final ProfileSetupController? controller;
  final AuthService? authService;
  final VoidCallback? onReload;
  const OnboardingWizard(
      {super.key,
      this.data,
      this.initialStep = OnboardingStep.name,
      this.controller,
      this.authService,
      this.onReload});
  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard>
    with WidgetsBindingObserver {
  late final ProfileSetupController setup = widget.controller ??
      ProfileSetupController(
          data: widget.data ?? OnboardingData(), step: widget.initialStep);
  final generation = AccountSession.generation;
  bool _busy = false, _dialog = false;
  String? _error;
  OnboardingData get data => setup.data;
  OnboardingStep get step => setup.step;
  bool get _active => mounted && AccountSession.isCurrent(generation);
  @override
  void initState() {
    super.initState();
    setup.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
  }

  void _refresh() {
    if (_active) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _active && !_busy) {
      setup.flush().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    setup.removeListener(_refresh);
    if (widget.controller == null) setup.dispose();
    super.dispose();
  }

  bool _valid(OnboardingStep target) {
    switch (target) {
      case OnboardingStep.name:
        return data.displayName.trim().isNotEmpty;
      case OnboardingStep.birthDate:
        try {
          data.toProfileUpdate();
          return data.birthDate != null;
        } catch (_) {
          return false;
        }
      case OnboardingStep.gender:
        return ['Man', 'Kvinna'].contains(data.gender);
      case OnboardingStep.interestedIn:
        return ['Män', 'Kvinnor', 'Alla'].contains(data.interestedIn);
      case OnboardingStep.bio:
        return data.promptKey.isEmpty || data.promptAnswer.trim().isNotEmpty;
      case OnboardingStep.photos:
        return data.photoUrls.length >= 2;
      default:
        return true;
    }
  }

  void _change(String field, String value) {
    data.update(field, value);
    setup.changed();
  }

  void _go(int index) {
    if (_busy || !_active) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    setup.changed(next: OnboardingStep.values[index]);
  }

  Future<void> _back() async {
    if (_busy || !_active) return;
    if (step.index > 0) {
      _go(step.index - 1);
    } else {
      await _leave();
    }
  }

  Future<void> _leave() async {
    if (_busy || _dialog || !_active) return;
    FocusScope.of(context).unfocus();
    _dialog = true;
    final leave = await confirmLeaveProfile(context);
    _dialog = false;
    if (leave != true || !_active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Never leave while the only copy of a new answer is still in memory.
      await setup.flush();
      if (!_active) return;
      await (widget.authService ?? AuthService())
          .logout()
          .timeout(const Duration(seconds: 15));
      if (!mounted || AccountSession.generation != generation + 1) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomePage()), (_) => false);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Kunde inte spara och lämna just nu. Dina val finns kvar här. Försök igen.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final last = DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 100, now.month, now.day);
    final initial =
        data.birthDate ?? DateTime(now.year - 25, now.month, now.day);
    final value = await showDatePicker(
        context: context,
        firstDate: first,
        lastDate: last,
        initialDate: initial.isBefore(first)
            ? first
            : initial.isAfter(last)
                ? last
                : initial);
    if (value != null && _active) {
      data.birthDate = value;
      setup.changed();
    }
  }

  Future<void> _photo() async {
    if (_busy || data.photoUrls.length >= 6 || !_active) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 82,
          maxWidth: 1920,
          maxHeight: 1920);
      if (file == null || !_active) return;
      final url = await PhotoService().uploadFile(File(file.path));
      if (!_active) return;
      if (!data.photoUrls.contains(url)) data.photoUrls.add(url);
      setup.changed();
      await setup.flush();
    } catch (failure) {
      if (_active) {
        setState(() => _error = failure is PhotoUploadException
            ? failure.message
            : 'Kunde inte lägga till bilden. Försök igen.');
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy || !_active) return;
    for (final required in [
      OnboardingStep.name,
      OnboardingStep.birthDate,
      OnboardingStep.gender,
      OnboardingStep.interestedIn,
      OnboardingStep.photos
    ]) {
      if (!_valid(required)) {
        _go(required.index);
        setState(() => _error = 'Det här behövs för att skapa din profil.');
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await setup.flush();
      await (widget.authService ?? AuthService())
          .saveOnboardingProfile(data)
          .timeout(const Duration(seconds: 30));
      if (!_active) return;
      await setup.completed();
      if (!mounted || !AccountSession.isCurrent(generation)) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (_) => false);
    } catch (_) {
      if (_active) {
        setState(() => _error =
            'Kunde inte bekräfta att profilen sparades. Dina val finns kvar. Försök igen.');
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  Future<void> _openExistingSession() async {
    if (!_active) return;
    if (setup.errorCode == 'profile_exists') await setup.completed();
    if (!mounted || !AccountSession.isCurrent(generation)) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const SplashPage(startupDelay: Duration.zero)),
        (_) => false);
  }

  Widget _text(String field, String label, {int lines = 1}) => TextFormField(
      key: ValueKey('onboarding-$field'),
      initialValue: data.toDraft()[field]?.toString() ?? '',
      onChanged: (value) => _change(field, value),
      inputFormatters: [
        TextInputFormatter.withFunction((previous, next) => next.text.length <=
                (field == 'bio'
                    ? 1000
                    : field == 'displayName'
                        ? 100
                        : 120)
            ? next
            : previous)
      ],
      maxLength: field == 'bio'
          ? 1000
          : field == 'displayName'
              ? 100
              : 120,
      minLines: lines,
      maxLines: lines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
          labelText: context.tr(label),
          filled: true,
          fillColor: const Color(0xFFF6F7F9),
          counterText: '',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none)));
  Widget _choices(Map<String, String> options, String field) => Column(
          children: options.entries.map((option) {
        final selected = data.toDraft()[field] == option.key;
        return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
                selected: selected,
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                        backgroundColor:
                            selected ? const Color(0xFFFFF0F3) : Colors.white,
                        side: BorderSide(
                            color: selected
                                ? const Color(0xFFFF4458)
                                : const Color(0xFFDFE2E7)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18))),
                    onPressed: () => _change(field, selected ? '' : option.key),
                    child: Row(children: [
                      Expanded(
                          child: Text(context.tr(option.value),
                              style: const TextStyle(
                                  color: Color(0xFF20242C), fontSize: 17))),
                      if (selected)
                        const Icon(Icons.check_rounded,
                            color: Color(0xFFFF4458))
                    ]))));
      }).toList());
  Widget _content() {
    final question = onboardingQuestions[step]!;
    if (step == OnboardingStep.intention) {
      const marks = {
        'Relationship': Icons.favorite_outline_rounded,
        'Marriage': Icons.diversity_1_outlined,
        'Date': Icons.coffee_outlined,
        'Serious': Icons.handshake_outlined,
        'Friendship': Icons.people_outline_rounded,
        'NotSure': Icons.explore_outlined
      };
      return LayoutBuilder(
          builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: question.options.entries.map((option) {
                final selected = data.intention == option.key;
                final width = MediaQuery.textScalerOf(context).scale(16) > 23 ||
                        constraints.maxWidth < 310
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return SizedBox(
                    width: width,
                    child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            backgroundColor: selected
                                ? const Color(0xFFFFEDF3)
                                : const Color(0xFFF7F8FA),
                            foregroundColor: const Color(0xFF20242C),
                            padding: const EdgeInsets.all(22),
                            side: BorderSide(
                                color: selected
                                    ? const Color(0xFFEC2863)
                                    : const Color(0xFFE8EBF0)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22))),
                        onPressed: () =>
                            _change('intention', selected ? '' : option.key),
                        child: Column(children: [
                          Icon(marks[option.key],
                              size: 32, color: const Color(0xFFEC2863)),
                          const SizedBox(height: 14),
                          Text(context.tr(option.value),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          if (selected)
                            const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Icon(Icons.check_rounded,
                                    color: Color(0xFFEC2863))),
                        ])));
              }).toList()));
    }
    if (question.options.isNotEmpty) {
      return _choices(question.options, question.field!);
    }
    switch (step) {
      case OnboardingStep.name:
        return _text('displayName', 'Ditt förnamn');
      case OnboardingStep.birthDate:
        return OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(data.birthDate == null
                ? context.l10n.chooseYourDateOfBirth
                : MaterialLocalizations.of(context)
                    .formatMediumDate(data.birthDate!)));
      case OnboardingStep.work:
        return Column(children: [
          _choices({'study': 'Pluggar just nu', 'work': 'Jobbar just nu'},
              'workStatus'),
          if (data.workStatus == 'study') ...[
            _text('studyPlace', 'Var pluggar du?'),
            const SizedBox(height: 16),
            _text('studySubject', 'Vad pluggar du?')
          ],
          if (data.workStatus == 'work') ...[
            _text('workPlace', 'Var jobbar du?'),
            const SizedBox(height: 16),
            _text('jobTitle', context.l10n.whatIsYourJobTitle)
          ]
        ]);
      case OnboardingStep.location:
        return Column(children: [
          _text('livePlace', 'Stad eller ort'),
          const SizedBox(height: 16),
          _text('originPlace', 'Var kommer du ifrån?')
        ]);
      case OnboardingStep.distance:
        return Column(children: [
          Text(context.l10n.value0Km((data.distanceKm).toString()),
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Slider(
              min: 1,
              max: 300,
              divisions: 299,
              value: data.distanceKm.toDouble(),
              label: '${data.distanceKm} km',
              onChanged: (value) {
                data.distanceKm = value.round();
                setup.changed();
              })
        ]);
      case OnboardingStep.height:
        return Column(children: [
          Text(
              data.heightCm == null
                  ? context.l10n.optional
                  : context.l10n.heightCentimeters((data.heightCm).toString()),
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Slider(
              min: 140,
              max: 260,
              divisions: 120,
              value: (data.heightCm ?? 170).clamp(140, 260).toDouble(),
              onChanged: (value) {
                data.heightCm = value.round();
                setup.changed();
              }),
          TextButton(
              onPressed: () {
                data.heightCm = null;
                setup.changed();
              },
              child: Text(context.l10n.clearSelection))
        ]);
      case OnboardingStep.bio:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _text('bio', 'Om mig', lines: 4),
          const SizedBox(height: 24),
          ConversationPromptEditor(
              promptKey: data.promptKey,
              answer: data.promptAnswer,
              onChanged: (key, answer) {
                data.promptKey = key;
                data.promptAnswer = answer;
                setup.changed();
              }),
        ]);
      case OnboardingStep.photos:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (setup.photosExpired)
            Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(context.l10n.aPhotoThatWasNotSavedHasExpiredAddIt)),
          Text(context.l10n.atLeastPhotosAreRequiredYouCanAddUpTo),
          const SizedBox(height: 16),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8),
              itemBuilder: (context, index) {
                if (index >= data.photoUrls.length) {
                  return OutlinedButton(
                      onPressed: _busy ? null : _photo,
                      child: const Icon(Icons.add, size: 32));
                }
                return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(
                          imageUrl: data.photoUrls[index],
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (_, __) =>
                              const ColoredBox(color: Color(0xFFF0F1F3)),
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined)),
                      Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: IconButton(
                              tooltip: context.l10n.removePhoto,
                              onPressed: _busy
                                  ? null
                                  : () {
                                      data.photoUrls.removeAt(index);
                                      setup.changed();
                                    },
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.white),
                              icon: const Icon(Icons.close)))
                    ]));
              }),
          const SizedBox(height: 12),
          Text(
              context.l10n.photosCountOfSix((data.photoUrls.length).toString()))
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
              child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(children: [
                Row(children: [
                  IconButton(
                      tooltip: step == OnboardingStep.name
                          ? context.l10n.leaveProfileSetup
                          : context.l10n.back,
                      onPressed: _busy ? null : _back,
                      icon: Icon(step == OnboardingStep.name
                          ? Icons.close
                          : Icons.arrow_back_ios_new_rounded)),
                  const Spacer(),
                  Flexible(
                      flex: 3,
                      child: TextButton(
                          onPressed: _busy ? null : _leave,
                          child: Text(context.l10n.continueLater,
                              textAlign: TextAlign.end))),
                ]),
                Text(
                    context.l10n.profileStep((step.index + 1).toString(),
                        (OnboardingStep.values.length).toString()),
                    style: const TextStyle(color: Color(0xFF667085))),
              ]),
            ),
            LinearProgressIndicator(
                value: (step.index + 1) / OnboardingStep.values.length,
                minHeight: 3,
                color: const Color(0xFFFF4458),
                backgroundColor: const Color(0xFFF0F1F3)),
            Expanded(
                child: SingleChildScrollView(
                    key: ValueKey(step),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(context.tr(onboardingQuestions[step]!.title),
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                  color: Color(0xFF20242C))),
                          const SizedBox(height: 12),
                          Text(
                              _validStepRequired
                                  ? context.l10n.weNeedThisToCreateYourProfile
                                  : context.l10n
                                      .optionalYouCanSkipThisAndChangeItLater,
                              style: const TextStyle(
                                  color: Color(0xFF667085), fontSize: 16)),
                          if (!_validStepRequired)
                            Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            if (step == OnboardingStep.bio &&
                                                data.promptAnswer
                                                    .trim()
                                                    .isEmpty) {
                                              data.promptKey = '';
                                              setup.changed();
                                            }
                                            _go(step.index + 1);
                                          },
                                    child: Text(context.l10n.skip))),
                          const SizedBox(height: 28),
                          AbsorbPointer(absorbing: _busy, child: _content()),
                          if (_error != null || setup.error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(context.tr(_error ?? setup.error!),
                                    style: const TextStyle(
                                        color: Color(0xFFB42318)))),
                          if (setup.error != null)
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        if ([
                                          'profile_exists',
                                          'session_expired'
                                        ].contains(setup.errorCode)) {
                                          _openExistingSession();
                                        } else if (setup.conflict) {
                                          widget.onReload?.call();
                                        } else {
                                          setup
                                              .flush()
                                              .catchError((Object _) {});
                                        }
                                      },
                                child: Text(setup.errorCode == 'profile_exists'
                                    ? context.l10n.openYourProfile
                                    : setup.errorCode == 'session_expired'
                                        ? context.l10n.signInAgain
                                        : setup.conflict
                                            ? context.l10n.openAccountDraft
                                            : context.l10n.trySavingAgain)),
                        ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (setup.service != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                                setup.error != null
                                    ? context.l10n.notSynced
                                    : setup.saving || setup.dirty
                                        ? context.l10n.saving
                                        : setup.revision == 0
                                            ? context
                                                .l10n.answersSavedAutomatically
                                            : context.l10n.savedToYourAccount,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF667085)))),
                      FilledButton(
                          onPressed: _busy || !_valid(step)
                              ? null
                              : () {
                                  if (step == OnboardingStep.photos) {
                                    _finish();
                                  } else {
                                    _go(step.index + 1);
                                  }
                                },
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: const Color(0xFF20242C),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28))),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(step == OnboardingStep.photos
                                  ? context.l10n.saveProfile
                                  : context.l10n.next)),
                    ])),
          ]))));
  bool get _validStepRequired => [
        OnboardingStep.name,
        OnboardingStep.birthDate,
        OnboardingStep.gender,
        OnboardingStep.interestedIn,
        OnboardingStep.photos
      ].contains(step);
}
