import 'dart:async';
import 'dart:convert';
import 'package:zullo_app/services/auth_service.dart';
import 'package:zullo_app/services/auth_storage.dart';
import 'package:zullo_app/services/onboarding_draft_service.dart';

class DraftStorage extends AuthStorage {
  final String user;
  DraftStorage([this.user = 'A']);
  @override
  Future<String?> getToken() async => 'token-$user';
  @override
  Future<String?> getUserId() async => user;
}

class MemoryDraftCache extends DraftCache {
  final Map<String, Map<String, dynamic>> values = {};
  @override
  Future<Map<String, dynamic>?> read(String user) async => values[user] == null
      ? null
      : Map<String, dynamic>.from(jsonDecode(jsonEncode(values[user])) as Map);
  @override
  Future<void> write(String user, Map<String, dynamic> value) async {
    values[user] =
        Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  }

  @override
  Future<void> clear(String user) async {
    values.remove(user);
  }
}

class FakeDraftService extends OnboardingDraftService {
  DraftSnapshot? remote;
  bool offline = false;
  Object? loadFailure;
  final saves = <DraftSnapshot>[];
  Future<DraftSnapshot> Function(int, int, Map<String, dynamic>)? saving;
  FakeDraftService({super.storage}) : super(cache: MemoryDraftCache());
  @override
  Future<DraftSnapshot?> load() async {
    if (loadFailure != null) throw loadFailure!;
    if (offline) throw TimeoutException('offline');
    return remote;
  }

  @override
  Future<DraftSnapshot> save(
      int revision, int step, Map<String, dynamic> data) async {
    saves.add(DraftSnapshot(revision, step, data));
    if (offline) throw TimeoutException('offline');
    if (saving != null) return saving!(revision, step, data);
    if ((remote?.revision ?? 0) != revision) {
      throw const DraftException('Changed elsewhere', code: 'draft_conflict');
    }
    return remote = DraftSnapshot(revision + 1, step, data);
  }
}

class RoutingAuth extends AuthService {
  RoutingAuth({super.client, super.storage});
  @override
  OnboardingDraftService get onboardingDrafts =>
      FakeDraftService(storage: DraftStorage());
}
