import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_application_1/widgets/app_nav.dart';
import '../core/user_model.dart';
import '../widgets/shared_widgets.dart';

class LiveVideoPage extends StatefulWidget {
  final UserModel user;
  const LiveVideoPage({super.key, required this.user});

  @override
  State<LiveVideoPage> createState() => _LiveVideoPageState();
}

class _LiveVideoPageState extends State<LiveVideoPage> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _hasError      = false;
  String _errorMsg    = '';
  int _cameraIndex    = 0;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initCamera(0);
  }

  Future<void> _initCamera(int index) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() { _hasError = true; _errorMsg = 'No camera found.'; });
        return;
      }
      await _controller?.dispose();
      _controller = null;
      setState(() => _isInitialized = false);

      _controller = CameraController(
        _cameras[index % _cameras.length],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        _hasError      = false;
        _cameraIndex   = index % _cameras.length;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _errorMsg = 'Camera error: ${e.description}'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _errorMsg = 'Error: $e'; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            // ── Title ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Live Video',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_cameras.length > 1) ...[
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => _initCamera(_cameraIndex + 1),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2B38),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Camera ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: _buildCameraView(),
                ),
              ),
            ),

            // ── Bottom nav ─────────────────────────────────────────
            AppBottomNav(currentIndex: 1, user: widget.user),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    if (_hasError) {
      return Container(
        color: const Color(0xFF0F1923),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              Text(_errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 14)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _initCamera(0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B8A9A), Color(0xFF080820)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: const Color(0xFF0F1923),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                  color: Color(0xFF6B8A9A), strokeWidth: 2.5),
              SizedBox(height: 16),
              Text('Starting camera…',
                  style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller!.value.previewSize?.height ?? 1,
            height: _controller!.value.previewSize?.width ?? 1,
            child: CameraPreview(_controller!),
          ),
        ),
        // ● LIVE badge
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.red),
                  ),
                  const SizedBox(width: 6),
                  const Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}