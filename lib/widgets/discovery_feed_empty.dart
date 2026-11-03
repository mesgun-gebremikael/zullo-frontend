import '../theme/zullo_palette.dart';
import 'package:flutter/material.dart';
import 'zullo_symbol.dart';

class DiscoveryFeedEmpty extends StatelessWidget {
  final bool paused;
  final VoidCallback onAction;
  const DiscoveryFeedEmpty(
      {super.key, required this.paused, required this.onAction});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxHeight < 560;
        return Center(
            child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: compact ? 88 : 156,
                          height: compact ? 88 : 156,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(colors: [
                                Color(0xFFFFE5EF),
                                ZulloPalette.canvas
                              ]),
                              border:
                                  Border.all(color: const Color(0xFFF0F2F6))),
                          child: Center(
                              child: Container(
                                  width: compact ? 64 : 96,
                                  height: compact ? 64 : 96,
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x0C20242C),
                                            blurRadius: 28,
                                            offset: Offset(0, 12))
                                      ]),
                                  child: paused
                                      ? const Icon(Icons.pause_rounded,
                                          size: 44, color: ZulloPalette.rose)
                                      : const Center(
                                          child: ZulloSymbol(
                                              kind: ZulloSymbolKind.discover,
                                              color: ZulloPalette.rose,
                                              size: 40))))),
                      SizedBox(height: compact ? 18 : 30),
                      const Text('ZULLO · UPPTÄCK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ZulloPalette.rose,
                              letterSpacing: 2,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text(
                          paused
                              ? 'En paus, i din takt.'
                              : 'Utöka din sökning',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ZulloPalette.ink,
                              fontSize: compact ? 26 : 30,
                              height: 1.15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      Text(
                          paused
                              ? 'Din profil är pausad. Dina matchningar och samtal finns kvar när du vill fortsätta.'
                              : 'Välj ett större område eller justera dina filter för att hitta fler personer.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: ZulloPalette.muted,
                              fontSize: 16,
                              height: 1.6)),
                      SizedBox(height: compact ? 20 : 28),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: onAction,
                              icon: Icon(
                                  paused
                                      ? Icons.play_arrow_rounded
                                      : Icons.tune_rounded,
                                  size: 20),
                              style: FilledButton.styleFrom(
                                  backgroundColor: ZulloPalette.rose,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 18)),
                              label: Text(paused
                                  ? 'Hantera paus'
                                  : 'Ändra filter'))),
                    ]))));
      });
}
