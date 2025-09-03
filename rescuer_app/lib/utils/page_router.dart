import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rescuer_app/screens/landing_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const LandingScreen(),
    ),
  ],
);
