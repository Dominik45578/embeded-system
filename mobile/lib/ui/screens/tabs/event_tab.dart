import 'package:flutter/material.dart';

class EventsTab extends StatelessWidget {
  const EventsTab({super.key});

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF00ADB5),
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text(
            'Historia Zdarzeń',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: const Center(
              child: Text(
                'Brak zapisanych zdarzeń',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}