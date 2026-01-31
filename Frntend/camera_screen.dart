import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'websocket_service.dart';

/// How often to grab a frame and push it to the server.
/// 500 ms ≈ 2 FPS — comfortable for most CPU-based CNN models.
/// Drop to 250 ms if your server can keep up.
const Duration _captureInterval = Duration(milliseconds: 500);

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // ─── Camera ───────────────────────────────────────────────────
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _camIndex = 0;
  bool _cameraReady = false;

  // ─── WebSocket ────────────────────────────────────────────────
  final WebSocketService _ws = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _predSub;

  // ─── Prediction state ─────────────────────────────────────────
  List<Map<String, dynamic>> _predictions = [];
  double _latencyMs = 0;

  // ─── Streaming toggle ─────────────────────────────────────────
  bool _isStreaming = false;
  Timer? _captureTimer;
  bool _busy = false; // guard against overlapping takePicture() calls

  // ─── Lifecycle ────────────────────────────────────────────────
  @override
  Future<void> initState() async {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cameras = await availableCameras();
    await _initCamera(0);
    await _ws.connect();
    _predSub = _ws.predictions.listen(_onPrediction);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStreaming();
    _ws.dispose();
    _predSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopStreaming();
      await _controller?.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      await _initCamera(_camIndex);
      if (_isStreaming) _startStreaming();
    }
  }

  // ─── Camera init ──────────────────────────────────────────────
  Future<void> _initCamera(int index) async {
    await _controller?.dispose();
    _controller = null;

    if (_cameras.isEmpty) {
      setState(() => _cameraReady = false);
      return;
    }

    _camIndex = index;
    final ctrl = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _controller = ctrl;
        _cameraReady = true;
      });
    } catch (_) {
      setState(() => _cameraReady = false);
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final wasStreaming = _isStreaming;
    _stopStreaming();
    await _initCamera((_camIndex + 1) % _cameras.length);
    if (wasStreaming) _startStreaming();
  }

  // ─── Streaming ────────────────────────────────────────────────
  void _startStreaming() {
    _isStreaming = true;
    _captureTimer =
        Timer.periodic(_captureInterval, (_) => _captureAndSend());
  }

  void _stopStreaming() {
    _isStreaming = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    _busy = false;
  }

  void _toggleStreaming() {
    setState(() {
      if (_isStreaming) {
        _stopStreaming();
      } else {
        _startStreaming();
      }
    });
  }

  // ─── Capture one frame and send ───────────────────────────────
  Future<void> _captureAndSend() async {
    if (_busy || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    _busy = true;

    try {
      final XFile pic = await _controller!.takePicture();
      final Uint8List bytes = await pic.readAsBytes();
      final String b64 = base64Encode(bytes);
      _ws.sendFrame(b64);
    } catch (_) {
      // Camera may have been disposed mid-capture — just skip
    } finally {
      _busy = false;
    }
  }

  // ─── Prediction callback ──────────────────────────────────────
  void _onPrediction(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      if (data.containsKey('predictions')) {
        _predictions = (data['predictions'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _latencyMs = (data['latency_ms'] as num).toDouble();
      }
    });
  }

  // ─── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraReady && _controller != null
          ? _buildMain()
          : _buildPlaceholder(),
    );
  }

  // ─── Placeholder when camera is not ready ────────────────────
  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        _cameras.isEmpty ? 'No camera found.' : 'Initialising camera…',
        style: const TextStyle(color: Colors.white70, fontSize: 16),
      ),
    );
  }

  // ─── Main layout ──────────────────────────────────────────────
  Widget _buildMain() {
    return Stack(
      children: [
        // Full-screen camera preview
        _cameraPreview(),
        // Prediction overlay at the top
        Align(
          alignment: Alignment.topCenter,
          child: _predictionOverlay(),
        ),
        // Controls at the bottom
        Align(
          alignment: Alignment.bottomCenter,
          child: _controlBar(),
        ),
      ],
    );
  }

  // ─── Camera preview ───────────────────────────────────────────
  Widget _cameraPreview() {
    final ctrl = _controller!;
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: ctrl.value.aspectRatio,
          child: CameraPreview(ctrl),
        ),
      ),
    );
  }

  // ─── Prediction overlay ───────────────────────────────────────
  Widget _predictionOverlay() {
    return Container(
      margin: const EdgeInsets.only(top: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Latency badge
          if (_isStreaming) _latencyBadge(),
          const SizedBox(height: 6),
          // Prediction cards
          ..._predictions.map((p) => _predCard(p)),
        ],
      ),
    );
  }

  Widget _latencyBadge() {
    final color =
        _latencyMs < 200 ? Colors.greenAccent : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '⚡ ${_latencyMs} ms',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _predCard(Map<String, dynamic> p) {
    final String label = p['label'] as String;
    final double conf = (p['confidence'] as num).toDouble();

    final Color barColor = conf > 70
        ? Colors.greenAccent
        : conf > 40
            ? Colors.amberAccent
            : Colors.redAccent;

    return Container(
      width: 230,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Text('${conf}%',
                  style: TextStyle(
                      color: barColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: conf / 100.0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom control bar ───────────────────────────────────────
  Widget _controlBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ctrlButton(
            _isStreaming ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
            _isStreaming ? Colors.redAccent : Colors.greenAccent,
            _toggleStreaming,
            _isStreaming ? 'Stop' : 'Start',
          ),
          if (_cameras.length > 1) ...[
            const SizedBox(width: 28),
            _ctrlButton(
              Icons.flip_camera_ios_outlined,
              Colors.white70,
              _switchCamera,
              'Flip',
            ),
          ],
        ],
      ),
    );
  }

  Widget _ctrlButton(
      IconData icon, Color color, VoidCallback onTap, String label) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 32),
            onPressed: onTap,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}