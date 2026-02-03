import 'package:flutter/material.dart';
import '../widgets/share_widgets/voice_command_banner.dart';

class HistoryLogsPage extends StatelessWidget {
  const HistoryLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'History Logs',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          const VoiceCommandBanner(
            command: 'Command: \'Show critical alerts only\'',
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HistoryLogCard(
                  time: '10:42 AM',
                  type: 'Obstacle',
                  description: 'Pole ahead',
                  distance: '2m',
                  isCritical: false,
                ),
                const SizedBox(height: 16),
                _HistoryLogCard(
                  time: '10:40 AM',
                  type: 'Hazard',
                  description: 'Construction work',
                  distance: '5m',
                  isCritical: true,
                ),
                const SizedBox(height: 16),
                _HistoryLogCard(
                  time: '10:38 AM',
                  type: 'Obstacle',
                  description: 'Pedestrian crossing',
                  distance: '1m',
                  isCritical: false,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'End of logs',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLogCard extends StatelessWidget {
  final String time;
  final String type;
  final String description;
  final String distance;
  final bool isCritical;

  const _HistoryLogCard({
    required this.time,
    required this.type,
    required this.description,
    required this.distance,
    required this.isCritical,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 4),
                  Text(
                    distance,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isCritical) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.warning, size: 18, color: Colors.grey[700]),
                  ],
                ],
              ),
            ],
          ),
          if (isCritical)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'CRITICAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
