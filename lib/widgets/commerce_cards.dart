import 'package:flutter/material.dart';

const commerceInk = Color(0xFF22262E);

/// ZULLO's letter mark, independent of store or competitor branding.
class ZulloMark extends StatelessWidget {
  final Color color;
  final double size;
  const ZulloMark({super.key, this.color = commerceInk, this.size = 42});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'ZULLO',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(size * .3)),
        alignment: Alignment.center,
        child: Text('Z',
            style: TextStyle(
                color: Colors.white,
                fontSize: size * .7,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic)),
      ));
}

class ProfilePurchaseCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool brand;
  final VoidCallback onTap;
  const ProfilePurchaseCard(
      {super.key,
      required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.brand = false});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: Row(children: [
              if (brand)
                ZulloMark(color: color)
              else
                Icon(icon, color: color, size: 44),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFF555D6A),
                            fontSize: 19,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: color,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ])),
              const SizedBox(width: 8),
              const Icon(Icons.add_circle_outline,
                  color: Color(0xFF9097A3), size: 30),
            ]),
          ),
        ),
      );
}

class PremiumBenefitsCard extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const PremiumBenefitsCard(
      {super.key, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE4CF8C))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                ZulloMark(color: Color(0xFFB38A23), size: 34),
                SizedBox(width: 10),
                Expanded(
                    child: Text('ZULLO Premium',
                        style: TextStyle(
                            color: commerceInk,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)))
              ]),
              const SizedBox(height: 18),
              const Text('Detta ingår',
                  style: TextStyle(
                      color: commerceInk,
                      fontSize: 21,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final benefit in [
                'Se vem som gillar dig',
                'Obegränsade likes',
                'Dölj aktivitetsstatus',
                'Inkognito',
                'Ångra en swipe',
                '3 Superlikes per vecka',
                '1 Boost per månad'
              ])
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Expanded(
                          child: Text(benefit,
                              style: const TextStyle(
                                  color: commerceInk, fontSize: 16))),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_rounded,
                          color: Color(0xFFB38A23), size: 23),
                    ])),
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8C35D),
                        foregroundColor: commerceInk,
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: onTap,
                    child: Text(
                        active ? 'Hantera Premium' : 'Se alla funktioner',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  )),
            ]),
          ),
        ),
      );
}
