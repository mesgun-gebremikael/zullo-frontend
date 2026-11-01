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
              title: Text('Avblockera ${row['displayName']}?'),
              content: const Text(
                  'Ni kan visas i Swipa igen om era inställningar passar. Ni måste matcha på nytt för att chatta. Den gamla chatten återställs inte.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Avbryt')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Avblockera')),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kunde inte avblockera. Försök igen.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Blockerade profiler')),
        body: !AccountSession.isCurrent(_generation)
            ? const SizedBox.shrink()
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(
                        onPressed: _load, child: const Text('Försök igen'))
                  ]))
                : _rows == null
                    ? const Center(child: CircularProgressIndicator())
                    : _rows!.isEmpty
                        ? const Center(
                            child: Text('Du har inga blockerade profiler.'))
                        : ListView(
                            children: _rows!
                                .map((row) => ListTile(
                                      title:
                                          Text(row['displayName'].toString()),
                                      trailing: TextButton(
                                          onPressed:
                                              _busy.contains(row['userId'])
                                                  ? null
                                                  : () => _unblock(row),
                                          child: const Text('Avblockera')),
                                    ))
                                .toList()),
      );
}
