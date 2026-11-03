import 'package:flutter/material.dart';

class HomeNavigation {
  const HomeNavigation._();

  static const jobseekerTitles = <String>[
    'Dashboard',
    'Lowongan',
    'Lamaran',
    'Tersimpan',
    'Profil',
  ];

  static const recruiterTitles = <String>[
    'Dashboard',
    'Lowongan',
    'Pelamar',
    'Profil',
  ];

  static const jobseekerRailDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Beranda'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.work_outline),
      selectedIcon: Icon(Icons.work),
      label: Text('Lowongan'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment),
      label: Text('Lamaran'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.bookmark_border),
      selectedIcon: Icon(Icons.bookmark),
      label: Text('Tersimpan'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profil'),
    ),
  ];

  static const recruiterRailDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.work_outline),
      selectedIcon: Icon(Icons.work),
      label: Text('Lowongan'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Pelamar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: Text('Profil'),
    ),
  ];

  static const jobseekerBottomItems = <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Beranda',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.work_outline),
      activeIcon: Icon(Icons.work),
      label: 'Lowongan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.assignment_outlined),
      activeIcon: Icon(Icons.assignment),
      label: 'Lamaran',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bookmark_border),
      activeIcon: Icon(Icons.bookmark),
      label: 'Tersimpan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  static const recruiterBottomItems = <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.work_outline),
      activeIcon: Icon(Icons.work),
      label: 'Lowongan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      activeIcon: Icon(Icons.people),
      label: 'Pelamar',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];
}
