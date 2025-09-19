import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:victim_app/screens/chatbot_screen.dart';
import 'package:victim_app/screens/home_screen.dart';
import 'package:victim_app/screens/landing_screen.dart' show LandingScreen;
import 'package:victim_app/screens/notifications_screen.dart';
import 'package:victim_app/screens/phonenumber_input.dart';
import 'package:victim_app/screens/otp_screen.dart';
import 'package:victim_app/screens/profile_screen.dart';
import 'package:victim_app/screens/report_disaster_screen.dart' show ReportDisasterScreen;
import 'package:victim_app/screens/shelter_screen.dart';
import 'package:victim_app/screens/signup_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/landing',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const PhoneInputScreen(),
    ),
    GoRoute(
      path: '/phone',
      builder: (BuildContext context, GoRouterState state) =>
          const PhoneInputScreen(),
    ),
    GoRoute(
      path: '/chatbot',
      builder: (BuildContext context, GoRouterState state) =>
          const ChatBot(),
    ),
     GoRoute(
      path: '/report',
      builder: (BuildContext context, GoRouterState state) =>
          const ReportDisasterScreen(),
    ),
     GoRoute(
      path: '/otp',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final phoneNumber = extra?['phoneNumber'] ?? '';
        
        return OTPScreen(phoneNumber: phoneNumber);
      },
    ),
     GoRoute(
      path: '/signup',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final phoneNumber = extra?['phoneNumber'] ?? '';
        
        return SignupScreen(phoneNumber: phoneNumber);
      },
    ),
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) =>
          const Homescreen(),
    ),
     GoRoute(
      path: '/shelter',
      builder: (BuildContext context, GoRouterState state) =>
          const ShelterScreen(),
    ),
      GoRoute(
      path: '/landing',
      builder: (BuildContext context, GoRouterState state) => const LandingScreen(),
    ),
     GoRoute(
      path: '/notifications',
      builder: (BuildContext context, GoRouterState state) =>
          const NotificationsScreen(),
    ),
     GoRoute(
      path: '/profile',
      builder: (BuildContext context, GoRouterState state) =>
          const ProfileScreen(),
    ),
  ],
);