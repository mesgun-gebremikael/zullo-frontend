import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'chat_page.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final AuthService _auth = AuthService();

  bool isLoading = true;
  String? error;
  List<dynamic> matches = [];
  List<dynamic> likesReceived = [];

  @override
  void initState() {
    super.initState();
    loadMatches();
  }

  DateTime? _tryParseUtc(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString();
    if (s.trim().isEmpty) return null;
    return DateTime.tryParse(s);
  }

  void _sortMatchesInUi(List<dynamic> list) {
    list.sort((a, b) {
      final aUnread = (a['hasUnread'] == true);
      final bUnread = (b['hasUnread'] == true);
      if (aUnread != bUnread) return aUnread ? -1 : 1;

      final aDt = _tryParseUtc(a['lastMessageAtUtc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      final bDt = _tryParseUtc(b['lastMessageAtUtc']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      return bDt.compareTo(aDt);
    });
  }

  Future<void> loadMatches() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
     final matchesData = await _auth.getMatches();
final matchesList = List<dynamic>.from(matchesData);

_sortMatchesInUi(matchesList);

// 🔥 Hämta likes-received också
final likesData = await _auth.getLikesReceived();
final likesList = List<dynamic>.from(likesData);

setState(() {
  matches = matchesList;
  likesReceived = likesList;
  isLoading = false;
});
    } catch (e) {
      setState(() {
        error = "Kunde inte ladda matches: $e";
        isLoading = false;
      });
    }
  }

  // ✅ NYTT: när chat stängs -> refresh matches så unread-dot uppdateras direkt
  Future<void> _openChat(dynamic m) async {
  final userId = (m["userId"] ?? "").toString();
  final name = (m["displayName"] ?? "").toString();
  final photoUrl = (m["photoUrl"] ?? "").toString();

 final shouldRefresh = await Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => ChatPage(
      userId: userId,
      displayName: name,
      photoUrl: photoUrl,
    ),
  ),
);

// ✅ Refresh bara om chatten säger true
if (shouldRefresh == true) {
  await loadMatches();
}

}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Matches"),
      ),
      body: RefreshIndicator(
        onRefresh: loadMatches,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 140),
                      Center(child: Text(error!)),
                    ],
                  )
                : matches.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 140),
                          Center(child: Text("Inga matches än")),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                        children: [
                          // ✅ LIKES (Premium-lås i MVP)
Container(
  margin: const EdgeInsets.only(bottom: 14),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: cs.surfaceContainerHighest.withOpacity(0.55),
  ),
  child: Row(
    children: [
      const Icon(Icons.lock),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          likesReceived.isEmpty
              ? "Inga nya likes än"
              : "${likesReceived.length} personer har gillat dig — Premium för att se vem",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  ),
),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                "New Matches",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 112,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: matches.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                                final m = matches[i];
                                final name =
                                    (m["displayName"] ?? "").toString();
                                final photoUrl =
                                    (m["photoUrl"] ?? "").toString();
                                final hasUnread = (m["hasUnread"] == true);

                                return InkWell(
                                  onTap: () => _openChat(m),
                                  borderRadius: BorderRadius.circular(18),
                                  child: SizedBox(
                                    width: 82,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(2.5),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: hasUnread
                                                  ? cs.primary
                                                  : cs.primary.withOpacity(0.55),
                                              width: 2,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                cs.surfaceContainerHighest,
                                            backgroundImage: photoUrl.isNotEmpty
                                                ? NetworkImage(photoUrl)
                                                : null,
                                            child: photoUrl.isEmpty
                                                ? Icon(Icons.person,
                                                    color: cs.onSurface
                                                        .withOpacity(0.7))
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            "Messages",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(matches.length, (i) {
                            final m = matches[i];
                            final name = (m["displayName"] ?? "").toString();
                            final age = (m["age"] ?? 0).toString();
                            final photoUrl =
                                (m["photoUrl"] ?? "").toString();
                            final hasUnread = (m["hasUnread"] == true);

                            final lastText =
                                (m['lastMessageText'] ?? '').toString().trim();
                            final subtitleText =
                                lastText.isNotEmpty ? lastText : "Säg hej 👋";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: cs.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                    color: Colors.black.withOpacity(0.06),
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                leading: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor:
                                          cs.surfaceContainerHighest,
                                      backgroundImage: photoUrl.isNotEmpty
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: photoUrl.isEmpty
                                          ? Icon(Icons.person,
                                              color: cs.onSurface
                                                  .withOpacity(0.7))
                                          : null,
                                    ),
                                    if (hasUnread)
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: cs.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: cs.surface, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  "$name, $age",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  subtitleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: hasUnread
                                        ? cs.onSurface
                                        : cs.onSurface.withOpacity(0.65),
                                  ),
                                ),
                                trailing: Icon(Icons.chevron_right,
                                    color: cs.onSurface.withOpacity(0.45)),
                                onTap: () => _openChat(m),
                              ),
                            );
                          }),
                        ],
                      ),
      ),
    );
  }
}