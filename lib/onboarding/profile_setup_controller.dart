import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/account_session.dart';
import '../services/onboarding_draft_service.dart';
import 'onboarding_data.dart';
import 'onboarding_steps.dart';

class ProfileSetupController extends ChangeNotifier {
  final OnboardingDraftService? service;
  final DraftCache? cache;
  final String? userId;
  final int generation = AccountSession.generation;
  OnboardingData data;
  OnboardingStep step;
  int revision;
  bool saving = false, dirty = false, conflict = false, photosExpired = false;
  String? error;
  String? errorCode;
  Timer? _timer;
  Future<void>? _running;
  int _changes = 0;
  bool _disposed = false, _complete = false;
  ProfileSetupController(
      {required this.data,
      this.step = OnboardingStep.name,
      this.revision = 0,
      this.service,
      this.cache,
      this.userId});
  bool get _active =>
      !_disposed && !_complete && AccountSession.isCurrent(generation);
  static String _canonical(Map<String, dynamic> data) =>
      jsonEncode(Map.fromEntries(
          data.entries.toList()..sort((a, b) => a.key.compareTo(b.key))));

  static Future<ProfileSetupController> load(OnboardingDraftService service,
      {DraftCache? cache, bool preferServer = false}) async {
    cache ??= service.cache;
    final user =
        await service.storage.getUserId().timeout(const Duration(seconds: 10));
    AccountSession.check(service.generation);
    if (user == null) throw const DraftException('Logga in igen.');
    Map<String, dynamic>? local;
    if (!preferServer) {
      try {
        local = await cache.read(user).timeout(const Duration(seconds: 10));
      } on FormatException {
        throw const DraftException(
            'Kunde inte läsa det lokala utkastet. Du kan öppna kontots sparade version.',
            code: 'draft_conflict');
      }
    }
    AccountSession.check(service.generation);
    DraftSnapshot? remote;
    String? offline;
    try {
      remote = await service.load();
    } on SessionChangedException {
      rethrow;
    } catch (failure) {
      if (failure is DraftException &&
          ['session_expired', 'profile_exists', 'draft_conflict']
              .contains(failure.code)) {
        rethrow;
      }
      if (local == null || preferServer) rethrow;
      offline =
          'Utkastet är sparat på enheten. Anslut till internet för att spara på kontot.';
    }
    AccountSession.check(service.generation);
    var values = remote?.data ?? <String, dynamic>{};
    var step = remote?.step ?? 0;
    var revision = remote?.revision ?? 0;
    var dirty = false;
    if (!preferServer &&
        local != null &&
        (local['dirty'] == true || offline != null)) {
      final localData = Map<String, dynamic>.from(local['data'] as Map);
      final same = remote != null &&
          _canonical(remote.data) == _canonical(localData) &&
          remote.step == local['step'];
      if (offline == null && (local['revision'] ?? 0) != revision && !same) {
        throw const DraftException(
            'Utkastet har ändrats på en annan enhet. Du kan öppna kontots sparade utkast. Dina lokala val ersätts först när du väljer det.',
            code: 'draft_conflict');
      }
      if (!same) {
        values = localData;
        step = local['step'] as int? ?? 0;
        revision = offline != null ? local['revision'] as int? ?? 0 : revision;
        dirty = true;
      }
    }
    final result = ProfileSetupController(
        data: OnboardingData.fromDraft(values),
        step: OnboardingStep
            .values[step.clamp(0, OnboardingStep.values.length - 1)],
        revision: revision,
        service: service,
        cache: cache,
        userId: user)
      ..dirty = dirty
      ..photosExpired = remote?.photosExpired ?? false
      ..error = offline;
    await result._writeLocal();
    if (dirty && offline == null) result._schedule();
    return result;
  }

  void changed({OnboardingStep? next}) {
    if (!_active) return;
    if (next != null) step = next;
    _changes++;
    dirty = true;
    error = null;
    notifyListeners();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (service != null && !conflict) {
      _timer = Timer(const Duration(milliseconds: 900), () {
        unawaited(_backgroundSave());
      });
    }
  }

  Future<void> _backgroundSave() async {
    try {
      await flush();
    } catch (_) {/* shown as unsaved, never a false saved state */}
  }

  Future<void> _writeLocal() async {
    if (cache == null || userId == null || !_active) return;
    await cache!.write(userId!, {
      'revision': revision,
      'step': step.index,
      'data': data.toDraft(),
      'dirty': dirty
    }).timeout(const Duration(seconds: 10));
    AccountSession.check(generation);
  }

  Future<void> flush() {
    _timer?.cancel();
    if (!_active) return Future.error(SessionChangedException());
    if (conflict) {
      return Future.error(DraftException(error ?? 'Öppna utkastet igen.',
          code: 'draft_conflict'));
    }
    return _running ??= _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    saving = true;
    if (_active) notifyListeners();
    try {
      while (_active && dirty) {
        final change = _changes;
        final payload = data.toDraft();
        final position = step.index;
        await _writeLocal();
        if (service != null) {
          final saved = await service!.save(revision, position, payload);
          AccountSession.check(generation);
          if (!_active) return;
          revision = saved.revision;
        }
        dirty = change != _changes;
        error = null;
        await _writeLocal();
      }
    } on SessionChangedException {
      rethrow;
    } catch (failure) {
      if (_active) {
        conflict =
            failure is DraftException && failure.code == 'draft_conflict';
        if (failure is DraftException &&
            failure.code == 'draft_photo_expired' &&
            failure.validPhotos != null) {
          data.photoUrls =
              data.photoUrls.where(failure.validPhotos!.contains).toList();
          photosExpired = true;
          _changes++;
          dirty = true;
          _schedule();
        }
        errorCode = failure is DraftException ? failure.code : null;
        error = failure is DraftException
            ? failure.message
            : 'Kunde inte spara utkastet. Dina val finns kvar här. Försök igen innan du lämnar.';
        await _writeLocal();
      }
      rethrow;
    } finally {
      saving = false;
      if (_active) notifyListeners();
    }
  }

  Future<void> completed() async {
    _complete = true;
    _timer?.cancel();
    if (cache != null && userId != null) {
      try {
        await cache!.clear(userId!);
      } catch (_) {/* completed server profile is authoritative */}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
