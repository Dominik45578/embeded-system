import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/model/device_event.dart';
import '../../../core/services/ble/ble_device_manger.dart';
import '../../widgets/custom_card.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final ScrollController _scrollController = ScrollController();
  final BleDeviceManager _manager = BleDeviceManager();
  bool _isFetchingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    // Automatyczne ładowanie danych przy wejściu na kartę
    _manager.fetchNextEventsPage(isRefresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isFetchingMore || !_manager.hasMoreEvents) return;

    setState(() => _isFetchingMore = true);
    await _manager.fetchNextEventsPage();

    if (mounted) {
      setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _handleRefresh() async {
    await _manager.fetchNextEventsPage(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, child) {
        final List<DeviceEvent> events = _manager.events;

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          color: const Color(0xFF00ADB5),
          backgroundColor: const Color(0xFF1E1E1E),
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            itemCount: events.isEmpty ? 2 : events.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    'Historia Zdarzeń',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                );
              }

              if (events.isEmpty && index == 1) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: const Center(
                    child: Text(
                      'Brak zapisanych zdarzeń',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
                    ),
                  ),
                );
              }

              if (index == events.length + 1) {
                return _manager.hasMoreEvents
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                  ),
                )
                    : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text(
                      'Koniec historii zdarzeń',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                );
              }

              final event = events[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildEventTile(event),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEventTile(DeviceEvent event) {
    final String formattedTime = DateFormat('HH:mm:ss').format(event.timestamp);
    final String formattedDate = DateFormat('dd.MM.yyyy').format(event.timestamp);

    final bool isBle = event.source == EventSource.bluetooth;
    final IconData sourceIcon = isBle ? Icons.bluetooth_searching_rounded : Icons.wifi_tethering_rounded;
    final Color sourceColor = isBle ? const Color(0xFF00ADB5) : Colors.purpleAccent;

    String displayMessage = event.message;
    Color messageColor = Colors.white;

    if (event.message.contains('UNLOCKED')) {
      displayMessage = 'Zamek otworzono';
      messageColor = Colors.green;
    } else if (event.message.contains('LOCKED')) {
      displayMessage = 'Zamek zamknięto';
      messageColor = Colors.red;
    } else if (event.message.contains('PIN_CHANGED')) {
      displayMessage = 'Zmieniono PIN';
      messageColor = Colors.orange;
    }

    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: sourceColor.withOpacity(0.12),
            radius: 20,
            child: Icon(sourceIcon, color: sourceColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayMessage,
                  style: TextStyle(color: messageColor, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  isBle ? 'Odebrano lokalnie przez Bluetooth' : 'Przesłano chmurą przez Wi-Fi',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedTime,
                style: TextStyle(color: sourceColor, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 2),
              Text(
                formattedDate,
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}