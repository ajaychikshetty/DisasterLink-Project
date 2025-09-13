import 'package:flutter/material.dart';
import '../services/global_unconscious_service.dart';

mixin UnconsciousActivityMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    // Update global service context when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalUnconsciousService.updateContext(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update context when dependencies change
    GlobalUnconsciousService.updateContext(context);
  }

  // Record user activity - call this on user interactions
  void recordUserActivity() {
    GlobalUnconsciousService.recordUserActivity();
  }
}