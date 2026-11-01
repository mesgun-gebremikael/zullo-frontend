import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/received_likes_summary.dart';
import 'premium_page.dart';
import 'services/account_session.dart';
import 'services/auth_service.dart';
import 'services/commerce_service.dart';
import 'services/matches_refresh_service.dart';
import 'services/refresh_coordinator.dart';
import 'services/relation_changes.dart';
import 'widgets/discovery_empty_state.dart';

/// Incoming interest only. This page never reads chat history or the match repository.
class LikesPage extends StatefulWidget {
  final AuthService? authService;
  const LikesPage({super.key, this.authService});
  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  late final _auth = widget.authService ?? AuthService();
  final _generation = AccountSession.generation;
  final _refresh = RefreshCoordinator();
  StreamSubscription<void>? _events;
  StreamSubscription<String>? _relations;
  StreamSubscription<int>? _sessions;
  ReceivedLikesSummary? _summary;
  List<dynamic> _likes = [];
  String? _error;
  String? _liking;
  bool get _active => mounted && AccountSession.isCurrent(_generation);
  @override
  void initState() {
    super.initState();
    _events = MatchesRefreshService.instance.stream
        .listen((_) => _load(invalidate: true));
    _relations = RelationChanges.stream.listen((_) {
      if (!_active) return;
      // Remove identities immediately while the authoritative counts refresh.
      setState(() {
        _likes = [];
        _summary = null;
      });
      _load(invalidate: true);
    });
    _sessions = AccountSession.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    _relations?.cancel();
    _sessions?.cancel();
    super.dispose();
  }

  Future<void> _load({bool invalidate = false}) => _refresh.run(() async {
        if (!_active) return;
        try {
          final revision = RelationChanges.revision;
          final results = await Future.wait<Object>(
              [_auth.getReceivedLikesSummary(), _auth.getLikesReceived()]);
          if (!_active || revision != RelationChanges.revision) return;
          setState(() {
            _summary = results[0] as ReceivedLikesSummary;
            _likes = results[1] as List<dynamic>;
            _error = null;
          });
        } catch (_) {
          if (_active) {
            setState(() {
              _error = 'Kunde inte hämta dina likes. Försök igen.';
            });
          }
        }
      }, invalidate: invalidate);
  Future<void> _premium() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PremiumPage()));
    if (_active) await _load(invalidate: true);
  }

  Future<void> _likeBack(Map<String, dynamic> like) async {
    if (_liking != null) return;
    setState(() => _liking = like['userId'].toString());
    try {
      final matched = await _auth.like(_liking!);
      if (!mounted || !AccountSession.isCurrent(_generation)) return;
      MatchesRefreshService.instance.requestRefresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(matched
              ? 'Ni har matchat! Öppna Chattar för att säga hej.'
              : 'Like skickad.')));
      await _load(invalidate: true);
    } on CommerceException catch (e) {
      if (mounted && AccountSession.isCurrent(_generation)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted && AccountSession.isCurrent(_generation)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kunde inte gilla tillbaka. Försök igen.')));
      }
    } finally {
      if (_active) setState(() => _liking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    final summary = _summary;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: const Text('Likes',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800))),
      body: RefreshIndicator(
          onRefresh: () => _load(invalidate: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_error != null)
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off_outlined,
                                      size: 44),
                                  const SizedBox(height: 16),
                                  Text(_error!, textAlign: TextAlign.center),
                                  TextButton(
                                      onPressed: () => _load(invalidate: true),
                                      child: const Text('Försök igen')),
                                ]))))
              else if (summary == null)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else ...[
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Text(
                            '${summary.totalCount} ${summary.totalCount == 1 ? 'like' : 'likes'}',
                            style: const TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w800)))),
                if (summary.totalCount == 0)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 90),
                          child: DiscoveryEmptyState(
                              likes: true,
                              premium: summary.canViewAll,
                              onAction: summary.canViewAll
                                  ? CommerceEvents.openDiscovery
                                  : _premium)))
                else ...[
                  if (summary.hiddenCount > 0) ...[
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                                '${summary.hiddenCount} ${summary.hiddenCount == 1 ? 'person har gillat dig' : 'personer har gillat dig'}. Se vilka med ZULLO Premium.',
                                style: const TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF626A77),
                                    height: 1.4)))),
                    SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverGrid.count(
                            crossAxisCount: 2,
                            childAspectRatio: .85,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            children: List.generate(
                                math.min(summary.hiddenCount, 6),
                                (_) => _lockedCard()))),
                  ],
                  SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.list(children: [
                        for (final raw in _likes)
                          _visibleCard(Map<String, dynamic>.from(raw as Map)),
                      ])),
                  if (!summary.canViewAll)
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: _upgradeButton())),
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ],
            ],
          )),
    );
  }

  Widget _upgradeButton() => FilledButton(
      onPressed: _premium,
      style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE8C35D),
          foregroundColor: const Color(0xFF22262E),
          padding: const EdgeInsets.all(18)),
      child: const Text('Se vem som gillar dig',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)));
  Widget _lockedCard() => Semantics(
      label: 'Dold like. Visa med Premium',
      button: true,
      child: InkWell(
          onTap: _premium,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF3E8C8),
                      Color(0xFFE5D3DE),
                      Color(0xFFE2E8EF)
                    ])),
            child: const Center(
                child: Icon(Icons.lock_rounded, color: Colors.white, size: 38)),
          )));
  Widget _visibleCard(Map<String, dynamic> like) {
    final photo = (like['photoUrl'] ?? '').toString();
    return Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                CircleAvatar(
                    radius: 28,
                    backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                    child: photo.isEmpty
                        ? const Icon(Icons.person_outline)
                        : null),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${like['displayName']}, ${like['age']}',
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w700)),
                      Text(
                          like['isSuperLike'] == true
                              ? 'Har supergillat dig'
                              : 'Gillar dig',
                          style: TextStyle(
                              color: like['isSuperLike'] == true
                                  ? Colors.blue
                                  : const Color(0xFF626A77))),
                    ])),
                if (like['isSuperLike'] == true)
                  const Icon(Icons.star_rounded, color: Colors.blue),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: _liking == null ? () => _likeBack(like) : null,
                      icon: const Icon(Icons.favorite_outline),
                      label: const Text('Gilla tillbaka'))),
            ])));
  }
}
