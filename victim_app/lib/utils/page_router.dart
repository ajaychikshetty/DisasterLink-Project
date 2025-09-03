import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:victim_app/screens/home_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/homescreen',
  routes: <RouteBase>[
        GoRoute(
          path: '/homescreen',
          builder: (BuildContext context, GoRouterState state) =>
              const Homescreen(),
        ),
  ],
);