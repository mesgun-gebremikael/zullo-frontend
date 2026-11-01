import 'package:flutter/material.dart';

class DiscoveryEmptyState extends StatelessWidget {
  final bool likes;
  final bool premium;
  final VoidCallback onAction;
  const DiscoveryEmptyState(
      {super.key,
      required this.likes,
      this.premium = false,
      required this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (likes)
            const Icon(Icons.favorite_rounded,
                size: 88, color: Color(0xFFE7E9ED))
          else
            SizedBox(
                width: 160,
                height: 170,
                child: Stack(alignment: Alignment.center, children: [
                  Transform.translate(
                      offset: const Offset(-12, 10),
                      child:
                          _card(Colors.white, const Color(0xFFBAC0C9), false)),
                  Transform.rotate(
                      angle: .25,
                      child: _card(const Color(0xFFF5FFF8),
                          const Color(0xFF5CCD89), true)),
                ])),
          const SizedBox(height: 30),
          Text(
              likes
                  ? (premium
                      ? 'Dina likes börjar här'
                      : 'Se vem som gillar dig')
                  : 'Börja swipa',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF555D6A),
                  fontSize: 25,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Text(
              likes
                  ? (premium
                      ? 'När någon gillar dig visas personen här.'
                      : 'Med ZULLO Premium kan du se personer som har gillat dig. Dina Superlikes visas här även utan Premium.')
                  : 'När du matchar med någon visas personen här, så att ni kan börja chatta.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF626A77), fontSize: 17, height: 1.5)),
          const SizedBox(height: 32),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                    backgroundColor: likes && !premium
                        ? const Color(0xFFE8C35D)
                        : const Color(0xFF22262E),
                    foregroundColor: likes && !premium
                        ? const Color(0xFF22262E)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 17)),
                child: Text(
                    likes && !premium ? 'Se vem som gillar dig' : 'Börja swipa',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              )),
        ]),
      );
  Widget _card(Color fill, Color stroke, bool front) => Container(
        width: 105,
        height: 145,
        decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: stroke, width: 3)),
        child: front
            ? Icon(Icons.favorite_outline_rounded, color: stroke, size: 52)
            : null,
      );
}
