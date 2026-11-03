import 'l10n/localization.dart';
import 'services/profile_images.dart';
import 'package:flutter/material.dart';
import 'services/account_session.dart';
import 'services/block_service.dart';

class BlockedProfilesPage extends StatefulWidget {
  final BlockService? service;
  const BlockedProfilesPage({super.key, this.service});
  @override
  State<BlockedProfilesPage> createState() => _BlockedProfilesPageState();
}

class _BlockedProfilesPageState extends State<BlockedProfilesPage> {
  late final _service = widget.service ?? BlockService();
  final _generation = AccountSession.generation;
  List<Map<String, dynamic>>? _rows;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _service.getBlockedUsers();
      if (!mounted || !AccountSession.isCurrent(_generation)) return;
      setState(() {
        _rows = rows;
        _error = null;
      });
    } catch (_) {
      if (mounted && AccountSession.isCurrent(_generation)) {
        setState(() => _error = 'Kunde inte hämta blockerade profiler.');
      }
    }
  }

  Future<void> _unblock(Map<String, dynamic> row) async {
    final id = row['userId'].toString();
    if (_busy.contains(id)) return;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(context.l10n.unblockPersonQuestion((row['displayName']).toString())),
              content: Text(context.l10n.youMaySeeEachOtherInSwipeAgainIfYour),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.l10n.unblock)),
              ],
            ));
    if (confirm != true || !mounted || !AccountSession.isCurrent(_generation)) {
      return;
    }
    setState(() => _busy.add(id));
    try {
      await _service.unblockUser(id);
      if (!mounted || !AccountSession.isCurrent(_generation)) return;
      setState(() => _rows?.removeWhere((item) => item['userId'] == id));
    } catch (_) {
      if (mounted && AccountSession.isCurrent(_generation)) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(
            content: Text(context.l10n.couldNotUnblockThisPersonTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.blockedProfiles)),
        body: !AccountSession.isCurrent(_generation)
            ? const SizedBox.shrink()
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(context.tr(_error!)),
                    TextButton(
                        onPressed: _load, child: Text(context.l10n.tryAgain))
                  ]))
                : _rows == null
                    ? const Center(child: CircularProgressIndicator())
                    : _rows!.isEmpty
                        ?  Center(
                            child: Text(context.l10n.noBlockedProfiles))
                        : ListView(
                            children: _rows!
                                .map((row) => Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(18, 6, 18, 6),
                                    child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFF5F6F8),
                                            borderRadius:
                                                BorderRadius.circular(24)),
                                        child: Row(children: [
                                          ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: SizedBox(
                                                  width: 78,
                                                  height: 98,
                                                  child: (row['photoUrl'] ?? '')
                                                          .toString()
                                                          .isEmpty
                                                      ? const ColoredBox(
                                                          color:
                                                              Color(0xFFE8EBF0),
                                                          child:
                                                              Icon(Icons.person_outline,
                                                                  size: 38))
                                                      : Image(
                                                          image: ProfileImages.thumbnail(
                                                              row['photoUrl']
                                                                  .toString()),
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __,
                                                                  ___) =>
                                                              const ColoredBox(
                                                                  color:
                                                                      Color(0xFFE8EBF0),
                                                                  child: Icon(Icons.person_outline, size: 38))))),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(
                                                    row['displayName']
                                                        .toString(),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w800)),
                                                if (row['age'] != null)
                                                  Text(context.l10n.value0Years((row['age']).toString())),
                                                const SizedBox(height: 6),
                                                Text(context.l10n.blocked,
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF697180))),
                                                TextButton(
                                                    onPressed: _busy.contains(
                                                            row['userId'])
                                                        ? null
                                                        : () => _unblock(row),
                                                    child: Text(
                                                        context.l10n.unblock)),
                                              ])),
                                        ]))))
                                .toList()),
      );
}
