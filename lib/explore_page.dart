import 'package:flutter/material.dart';
import 'services/commerce_service.dart';

class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Explore',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800))),
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFEEF3), Color(0xFFF1F3FC)])),
                  child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.explore_outlined,
                            size: 54, color: Color(0xFFE6296B)),
                        SizedBox(height: 24),
                        Text('Någon ny börjar med ett hej',
                            style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.2)),
                        SizedBox(height: 16),
                        Text(
                            'Upptäck profiler som passar dina val. Du bestämmer vem du vill lära känna.',
                            style: TextStyle(fontSize: 17, height: 1.5)),
                      ])),
              const SizedBox(height: 28),
              const Text('Upptäck på ditt sätt',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_rounded),
                  title: Text('Dina val styr'),
                  subtitle: Text(
                      'Välj intresse, ålder och avstånd i inställningarna för Swipa.')),
              const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.favorite_outline),
                  title: Text('Gilla och matcha'),
                  subtitle: Text(
                      'När ni gillar varandra kan ni börja prata i Chattar.')),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: CommerceEvents.openDiscovery,
                      child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Upptäck profiler')))),
            ])),
      );
}
