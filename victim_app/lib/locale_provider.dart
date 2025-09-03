// locale_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// null = follow system locale
final localeProvider = StateProvider<Locale?>((ref) => null);
