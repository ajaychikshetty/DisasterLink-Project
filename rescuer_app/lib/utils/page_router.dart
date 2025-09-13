import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rescuer_app/screens/home_screen.dart';
import 'package:rescuer_app/screens/landing_screen.dart';
import 'package:rescuer_app/screens/notification_screen.dart' show  NotificationsScreen;
import 'package:rescuer_app/screens/victims_page.dart';
import 'package:rescuer_app/screens/victims_screen.dart' show VictimsScreen;

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const LandingScreen(),
    ),
     GoRoute(
      path: '/notifications',
      builder: (BuildContext context, GoRouterState state) =>
          const NotificationsScreen(),
    ),
     GoRoute(
      path: '/victims',
      builder: (BuildContext context, GoRouterState state) =>
          const VictimsScreen(),
    ),
     GoRoute(
      path: '/victimspage',
      builder: (BuildContext context, GoRouterState state) =>
          const VictimsPage(),
    ),
    
     GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) =>
          const Homescreen(),
    ),
  ],
);
