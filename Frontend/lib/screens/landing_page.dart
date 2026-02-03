import 'package:flutter/material.dart';
import '../widgets/landing_widgets/info_section.dart';
import '../widgets/landing_widgets/app_logo.dart';
import 'detection_active_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.black),
      body: GestureDetector(
        onTap: () {
          // Handle tap to start detection
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DetectionActivePage(),
            ),
          );
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const AppLogo(),
                  const SizedBox(height: 24),
                  // App Name
                  const Text(
                    'VoxEye',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  const Text(
                    'Voice-guided navigation assistant',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  // Start Detection Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle start detection
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DetectionActivePage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Start Detection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Microphone Icon
                  Icon(Icons.mic, size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 48),
                  // Voice Command Section
                  InfoSection(
                    icon: Icons.chat_bubble_outline,
                    title: 'VOICE COMMAND',
                    description:
                        'System says: \'Welcome to VoxEye. Say Start detection or tap the screen.\'',
                  ),
                  const SizedBox(height: 24),
                  // Gesture Section
                  InfoSection(
                    icon: Icons.touch_app,
                    title: 'GESTURE',
                    description:
                        'Tap anywhere on screen also activates detection',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
