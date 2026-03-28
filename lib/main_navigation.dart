import 'dart:ui';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'matches_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),               // Swipa
    MatchesPage(),            // Explore (tillfällig)
    MatchesPage(),            // Likes (tillfällig)
    MatchesPage(),            // Chattar (tillfällig)
    _ProfileTabPlaceholder(), // Profil (tillfällig)
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_selectedIndex],
      bottomNavigationBar: SafeArea(
  top: false,
minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),  child: ClipRRect(
    borderRadius: BorderRadius.circular(34),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        height: 64,
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),        decoration: BoxDecoration(
         gradient: LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Colors.white.withOpacity(0.08),
    Colors.white.withOpacity(0.04),
  ],
),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
  color: Colors.white.withOpacity(0.15),
  width: 1,
),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavItem(
              icon: Icons.local_fire_department_outlined,
              activeIcon: Icons.local_fire_department,
              label: 'Swipa',
              isActive: _selectedIndex == 0,
              activeColor: const Color(0xFFFF4458),
              onTap: () => _onItemTapped(0),
            ),
            _NavItem(
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore,
              label: 'Explore',
              isActive: _selectedIndex == 1,
              activeColor: Colors.white,
              onTap: () => _onItemTapped(1),
            ),
            _NavItem(
              icon: Icons.favorite_border,
              activeIcon: Icons.favorite,
              label: 'Likes',
              isActive: _selectedIndex == 2,
              activeColor: Colors.white,
              onTap: () => _onItemTapped(2),
            ),
            _NavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: 'Chattar',
              isActive: _selectedIndex == 3,
              activeColor: Colors.white,
              onTap: () => _onItemTapped(3),
            ),
            _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profil',
              isActive: _selectedIndex == 4,
              activeColor: Colors.white,
              onTap: () => _onItemTapped(4),
            ),
          ],
        ),
      ),
    ),
  ),
),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const inactiveColor = Colors.white;
    const inactiveTextColor = Color(0xE6FFFFFF);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeOut,
  padding: EdgeInsets.symmetric(
    horizontal: isActive ? 14 : 4,
    vertical: isActive ? 8 : 4,
  ),
  decoration: BoxDecoration(
    color: isActive
    ? Colors.white.withOpacity(0.18)
    : Colors.transparent,
    borderRadius: BorderRadius.circular(999),
  ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
               Icon(
  isActive ? activeIcon : icon,
  color: isActive ? Colors.white : inactiveColor,
  size: isActive ? 25 : 22,
),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
color: isActive ? Colors.white : inactiveTextColor,                    fontSize: isActive ? 10.5 : 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTabPlaceholder extends StatelessWidget {
  const _ProfileTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Text(
            'Profil kommer snart',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}