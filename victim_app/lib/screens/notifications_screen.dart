import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:victim_app/widgets/bottom_navbar.dart' show Bottom_NavBar;
import '../services/sms_service.dart';
import '../l10n/app_localizations.dart';
import '../mixins/unconscious_activity_mixin.dart';
import 'dart:async';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with WidgetsBindingObserver, UnconsciousActivityMixin {
  List<AppSmsMessage> _smsMessages = [];
  bool _isLoading = true;
  bool _isRealTimeActive = false;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<AppSmsMessage>>? _smsSubscription;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeRealTimeMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRealTimeMonitoring();
    _searchController.dispose();
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isRealTimeActive) {
          _initializeRealTimeMonitoring();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Optionally pause monitoring when app is not active
        // _stopRealTimeMonitoring();
        break;
      case AppLifecycleState.detached:
        _stopRealTimeMonitoring();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeRealTimeMonitoring() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Start real-time monitoring with 3-second intervals
      await SmsService.startRealTimeMonitoring(
        interval: const Duration(seconds: 3),
      );

      // Subscribe to real-time SMS updates
      _smsSubscription = SmsService.smsStream.listen(
        (messages) {
          if (mounted) {
            setState(() {
              _smsMessages = messages;
              _isLoading = false;
              _isRealTimeActive = true;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isRealTimeActive = false;
            });
            _showErrorSnackBar('Real-time monitoring error: $error');
          }
        },
      );

      // Initial load
      await _loadSmsMessages();

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRealTimeActive = false;
        });
        _showErrorSnackBar('Failed to start real-time monitoring: $e');
        // Fallback to manual loading
        await _loadSmsMessages();
      }
    }
  }

  Future<void> _stopRealTimeMonitoring() async {
    await _smsSubscription?.cancel();
    _smsSubscription = null;
    await SmsService.stopRealTimeMonitoring();
    if (mounted) {
      setState(() {
        _isRealTimeActive = false;
      });
    }
  }

  Future<void> _loadSmsMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await SmsService.getSmsFromLast7Days();
      if (mounted) {
        setState(() {
          _smsMessages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load SMS messages: $e');
      }
    }
  }

  Future<void> _searchSms() async {
    if (_searchKeyword.trim().isEmpty) {
      if (_isRealTimeActive) {
        // If real-time is active, we don't need to reload
        return;
      } else {
        await _loadSmsMessages();
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await SmsService.searchSmsByKeyword(_searchKeyword);
      if (mounted) {
        setState(() {
          _smsMessages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to search SMS: $e');
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_isRealTimeActive) {
      // Force refresh the real-time monitoring
      await SmsService.forceRefresh();
    } else {
      await _loadSmsMessages();
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              _initializeRealTimeMonitoring();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      bottomNavigationBar: Bottom_NavBar(indexx: 3),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 80,
              floating: true,
              pinned: false,
              backgroundColor: isDark ? Colors.black : Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.notifications,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              ),
              actions: [
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _onRefresh,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search SMS messages...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchKeyword = '';
                              });
                              if (!_isRealTimeActive) {
                                _loadSmsMessages();
                              }
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchKeyword = value;
                    });
                    // Implement debounced search for real-time filtering
                    if (value.isNotEmpty) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchKeyword == value) {
                          _searchSms();
                        }
                      });
                    }
                  },
                  onSubmitted: (_) => _searchSms(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_smsMessages.length} messages',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (SmsService.isMonitoringActive)
                      Text(
                        'Live updates every 3s',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading SMS messages...'),
                        ],
                      ),
                    )
                  : _smsMessages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sms,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchKeyword.isEmpty
                                    ? 'No SMS messages in the last 7 days'
                                    : 'No SMS messages found for "$_searchKeyword"',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _initializeRealTimeMonitoring,
                                child: const Text('Start Real-time Monitoring'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _smsMessages.length,
                          itemBuilder: (context, index) {
                            final message = _smsMessages[index];
                            return _buildSmsCard(message, isDark, index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsCard(AppSmsMessage message, bool isDark, int index) {
    final isNew = _isRealTimeActive && 
        DateTime.now().difference(message.date).inMinutes < 1;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: isNew ? 4 : 1,
      child: Container(
        decoration: isNew ? BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green, width: 1),
        ) : null,
        child: ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green,
                child: Text(
                  message.sender.isNotEmpty ? message.sender[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isNew)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  message.sender,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                message.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(message.date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          onTap: () => _showSmsDetail(message, isDark),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showSmsDetail(AppSmsMessage message, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          message.sender,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From: ${message.address}',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${_formatFullDate(message.date)}',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message.body,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}