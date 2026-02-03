import 'package:flutter/material.dart';
import '../widgets/error_state_widgets/error_card.dart';
import '../widgets/error_state_widgets/warning_card.dart';

class ErrorStatesPage extends StatelessWidget {
  const ErrorStatesPage({super.key});

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
          'Error States',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ErrorCard(
            icon: Icons.videocam_off_outlined,
            title: 'Camera Unavailable',
            description: 'Cannot access camera feed. Check permissions.',
            voiceCommand: 'Audio: \'Camera unavailable. Retrying...\'',
            buttonText: 'Retry Connection',
            onButtonPressed: () {},
          ),
          const SizedBox(height: 16),
          const WarningCard(
            icon: Icons.battery_alert,
            title: 'Low Battery (15%)',
            description: 'Detection may stop soon to preserve power.',
            note: 'Vibration: Long continuous pulse',
          ),
          const SizedBox(height: 16),
          // Permission Required
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 2),
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 32, color: Colors.grey[600]),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Permission Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
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
