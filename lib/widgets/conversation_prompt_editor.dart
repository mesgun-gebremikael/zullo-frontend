import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const conversationPrompts = <String, String>{
  'small_joy': 'En liten sak som gör min dag',
  'unexpected_skill': 'En oväntad talang jag har',
  'weekend': 'Min perfekta lediga dag',
  'ask_me': 'Fråga mig gärna om',
  'first_date': 'En första dejt jag skulle gilla',
};

class ConversationPromptEditor extends StatelessWidget {
  final String promptKey, answer;
  final void Function(String key, String answer) onChanged;
  const ConversationPromptEditor(
      {super.key,
      required this.promptKey,
      required this.answer,
      required this.onChanged});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Välj en samtalsfråga',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('En detalj om dig som gör det lättare att börja prata.'),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey('question-$promptKey'),
          initialValue:
              conversationPrompts.containsKey(promptKey) ? promptKey : '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Din fråga'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Ingen fråga vald')),
            ...conversationPrompts.entries.map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value,
                    maxLines: 2, overflow: TextOverflow.ellipsis)))
          ],
          onChanged: (key) {
            if (key != null && key != promptKey) onChanged(key, '');
          },
        ),
        if (conversationPrompts.containsKey(promptKey)) ...[
          const SizedBox(height: 14),
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
              decoration: const InputDecoration(
                  labelText: 'Ditt svar', alignLabelWithHint: true),
              onChanged: (value) => onChanged(promptKey, value)),
          TextButton(
              onPressed: () => onChanged('', ''),
              child: const Text('Ta bort samtalsfrågan')),
        ],
      ]);
}
