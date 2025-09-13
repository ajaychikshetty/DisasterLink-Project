import 'dart:async';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
class AppSmsMessage {
  final String sender;
  final String body;
  final DateTime date;
  final String address;
  final String? id; // Add ID for tracking duplicates

  AppSmsMessage({
    required this.sender,
    required this.body,
    required this.date,
    required this.address,
    this.id,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSmsMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SmsService {
  static final SmsQuery _query = SmsQuery();
  static Timer? _pollingTimer;
  static DateTime? _lastFetchTime;
  static final StreamController<List<AppSmsMessage>> _smsStreamController =
      StreamController<List<AppSmsMessage>>.broadcast();
  static List<AppSmsMessage> _cachedMessages = [];

  // Stream for real-time SMS updates
  static Stream<List<AppSmsMessage>> get smsStream => _smsStreamController.stream;

  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status == PermissionStatus.granted;
  }

  // Start real-time SMS monitoring
  static Future<void> startRealTimeMonitoring({
    Duration interval = const Duration(seconds: 5), // Check every 5 seconds
  }) async {
    await stopRealTimeMonitoring(); // Stop any existing monitoring

    final hasPermission = await requestSmsPermission();
    if (!hasPermission) {
      throw Exception('SMS permission denied for real-time monitoring');
    }

    // Initial fetch
    _lastFetchTime = DateTime.now().subtract(const Duration(hours: 24));
    await _fetchAndBroadcastSms();

    // Start periodic polling
    _pollingTimer = Timer.periodic(interval, (_) async {
      await _fetchAndBroadcastSms();
    });

    print('Real-time SMS monitoring started with ${interval.inSeconds}s interval');
  }

  // Stop real-time SMS monitoring
  static Future<void> stopRealTimeMonitoring() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    print('Real-time SMS monitoring stopped');
  }

  // Internal method to fetch and broadcast SMS updates
  static Future<void> _fetchAndBroadcastSms() async {
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      // Query SMS messages
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 200, // Increased count for better coverage
      );

      // Convert to AppSmsMessage and filter by date
      final recentMessages = messages
          .where((message) => 
              message.date != null && 
              message.date!.isAfter(cutoff) &&
              ((message.body?.contains('DISASTERLINKx9040') ?? false)))
          .map((message) => AppSmsMessage(
                sender: message.sender ?? 'Unknown',
                body: message.body ?? '',
                date: message.date!,
                address: message.address ?? '',
                id: message.id?.toString(),
              ))
          .toList();

      // Sort by date (newest first)
      recentMessages.sort((a, b) => b.date.compareTo(a.date));

      // Check for new messages since last fetch
      final newMessages = _lastFetchTime != null
          ? recentMessages.where((msg) => msg.date.isAfter(_lastFetchTime!)).toList()
          : <AppSmsMessage>[];

      if (newMessages.isNotEmpty) {
        print('Found ${newMessages.length} new SMS messages');
        // Notify about new messages if needed
        _onNewMessagesReceived(newMessages);
      }

      // Update cache and broadcast all recent messages
      _cachedMessages = recentMessages;
      _smsStreamController.add(recentMessages);
      _lastFetchTime = now;

    } catch (e) {
      print('Error in real-time SMS fetch: $e');
      // Broadcast cached messages on error to maintain UI state
      _smsStreamController.add(_cachedMessages);
    }
  }

  // Callback for new messages (can be customized)
  static void _onNewMessagesReceived(List<AppSmsMessage> newMessages) {
    // You can add custom logic here like:
    // - Show notifications
    // - Play sounds
    // - Trigger specific actions
    for (final message in newMessages) {
      print('New SMS from ${message.sender}: ${message.body}');
    }
  }

  // Enhanced method that uses cached data when available
  static Future<List<AppSmsMessage>> getSmsFromLast7Days() async {
    try {
      // Return cached data if real-time monitoring is active
      if (_pollingTimer?.isActive == true && _cachedMessages.isNotEmpty) {
        return _cachedMessages;
      }

      // Otherwise, fetch fresh data
      final hasPermission = await requestSmsPermission();
      if (!hasPermission) {
        throw Exception('SMS permission denied');
      }

      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 200,
      );

      final recentMessages = messages
          .where((message) => 
              message.date != null && 
              message.date!.isAfter(cutoff) &&
              ((message.body?.contains('DISASTERLINKx9040') ?? false)))
          .map((message) => AppSmsMessage(
                sender: message.sender ?? 'Unknown',
                body: message.body ?? '',
                date: message.date!,
                address: message.address ?? '',
                id: message.id?.toString(),
              ))
          .toList();

      recentMessages.sort((a, b) => b.date.compareTo(a.date));
      _cachedMessages = recentMessages;
      return recentMessages;

    } catch (e) {
      print('Error fetching SMS: $e');
      return _cachedMessages; // Return cached data on error
    }
  }

  static Future<List<AppSmsMessage>> searchSmsByKeyword(String keyword) async {
    try {
      // Use cached data if available for faster search
      if (_cachedMessages.isNotEmpty) {
        final filteredMessages = _cachedMessages
            .where((message) => 
                message.body.toLowerCase().contains(keyword.toLowerCase()) ||
                message.sender.toLowerCase().contains(keyword.toLowerCase()))
            .toList();
        return filteredMessages;
      }

      // Otherwise fetch and search
      final hasPermission = await requestSmsPermission();
      if (!hasPermission) {
        throw Exception('SMS permission denied');
      }

      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 300,
      );

      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(hours: 24));

      final filteredMessages = messages
          .where((message) => 
              message.date != null && 
              message.date!.isAfter(cutoff) &&
              ((message.body?.contains('DISASTERLINKx9040') ?? false)) &&
              ((message.body?.toLowerCase().contains(keyword.toLowerCase()) ?? false) ||
               (message.sender?.toLowerCase().contains(keyword.toLowerCase()) ?? false)))
          .map((message) => AppSmsMessage(
                sender: message.sender ?? 'Unknown',
                body: message.body ?? '',
                date: message.date!,
                address: message.address ?? '',
                id: message.id?.toString(),
              ))
          .toList();

      filteredMessages.sort((a, b) => b.date.compareTo(a.date));
      return filteredMessages;
    } catch (e) {
      print('Error searching SMS: $e');
      return [];
    }
  }

  // Check if real-time monitoring is active
  static bool get isMonitoringActive => _pollingTimer?.isActive == true;

  // Get cached messages count
  static int get cachedMessagesCount => _cachedMessages.length;

  // Force refresh (useful for pull-to-refresh)
  static Future<void> forceRefresh() async {
    await _fetchAndBroadcastSms();
  }

  // Dispose resources
  static void dispose() {
    stopRealTimeMonitoring();
    _smsStreamController.close();
    _cachedMessages.clear();
  }
}