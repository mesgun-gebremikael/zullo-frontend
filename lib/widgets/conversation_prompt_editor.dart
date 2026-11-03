import '../l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const conversationPrompts = <String, String>{
  'small_joy': 'En liten sak som gör min dag',
  'unexpected_skill': 'En oväntad talang jag har',
  'weekend': 'Min perfekta lediga dag',
  'ask_me': 'Fråga mig gärna om',
  'first_date': 'En första dejt jag skulle gilla',
  'perfect_evening': 'Min perfekta vardagskväll',
  'travel_story': 'En resa jag gärna berättar om',
  'food_opinion': 'En maträtt jag gärna lagar åt dig',
  'teach_me': 'Det här vill jag lära mig',
  'simple_plan': 'En spontan idé jag säger ja till',
  'surprise': 'En oväntad sida av mig',
  'talk_all_night': 'Det här kan jag prata om i timmar',
};

class ConversationPromptEditor extends StatelessWidget {
  final String promptKey, answer;
  final void Function(String key, String answer) onChanged;
  const ConversationPromptEditor(
      {super.key,
      required this.promptKey,
      required this.answer,
      required this.onChanged});
  Future<void> _choose(BuildContext context) async {
    final key = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: .75,
            minChildSize: .4,
            maxChildSize: .95,
            builder: (context, scroll) => SafeArea(
                    child: ListView(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        children: [
                      Text(context.l10n.chooseAConversationPrompt,
                          style: TextStyle(
                              fontSize: 25, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Text(context.l10n
                          .chooseSomethingThatSoundsLikeYouYourAnswerCouldStart),
                      const SizedBox(height: 20),
                      ...conversationPrompts.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                              color: entry.key == promptKey
                                  ? const Color(0xFFFFEDF3)
                                  : const Color(0xFFF5F6F8),
                              borderRadius: BorderRadius.circular(20),
                              child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 8),
                                  title: Text(context.tr(entry.value),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  leading: const Icon(
                                      Icons.format_quote_rounded,
                                      color: Color(0xFFEC2863)),
                                  trailing: entry.key == promptKey
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFFEC2863))
                                      : const Icon(Icons.add_rounded),
                                  onTap: () =>
                                      Navigator.pop(context, entry.key)))))
                    ]))));
    if (context.mounted && key != null && key != promptKey) onChanged(key, '');
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.l10n.aLittleAboutMe,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(context.l10n.giveSomeoneAReasonToAskYouMore),
        const SizedBox(height: 16),
        OutlinedButton(
            onPressed: () => _choose(context),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                foregroundColor: const Color(0xFF20242C),
                side: BorderSide(
                    color: promptKey.isEmpty
                        ? const Color(0xFFE2E6EC)
                        : const Color(0xFFEC2863)),
                backgroundColor: promptKey.isEmpty
                    ? const Color(0xFFF7F8FA)
                    : const Color(0xFFFFF5F8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22))),
            child: Row(children: [
              const Icon(Icons.format_quote_rounded, color: Color(0xFFEC2863)),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(
                      context.tr(conversationPrompts[promptKey] ??
                          'Välj en samtalsfråga'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded)
            ])),
        if (conversationPrompts.containsKey(promptKey)) ...[
          const SizedBox(height: 16),
          TextFormField(
              key: ValueKey('answer-$promptKey'),
              initialValue: answer,
              minLines: 2,
              maxLines: 5,
              maxLength: 250,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, value) =>
                    value.text.length <= 250 ? value : oldValue)
              ],
              decoration: InputDecoration(
                  labelText: context.l10n.yourAnswer,
                  hintText: context.l10n.writeSomethingPersonal,
                  alignLabelWithHint: true),
              onChanged: (value) => onChanged(promptKey, value)),
          TextButton(
              onPressed: () => onChanged('', ''),
              child: Text(context.l10n.removeConversationPrompt)),
        ],
      ]);
}
