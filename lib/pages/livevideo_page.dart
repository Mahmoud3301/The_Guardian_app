import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/widgets/app_nav.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/app_colors.dart';
import '../core/user_model.dart';
import '../core/security_event_store.dart';
import '../services/backend_service.dart';
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
  bool _hasError = false;
  String _errorMsg = '';
  int _cameraIndex = 0;
  List<CameraDescription> _cameras = [];
  WebSocketChannel? _channel;
  Timer? _frameTimer;
  bool _sending = false;
  bool _isStreaming = false;
  Uint8List? _processedFrame;
  String _recognitionLabel = 'Waiting recognition...';
  String _recognitionName = '';
  double? _recognitionDistance;
  DateTime? _lastUnknownNotificationAt;
  Uint8List? _lastFaceCrop;

  // Backend connectivity
  bool _backendReachable = false;
  bool _checkingBackend = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  final _backend = BackendService.instance;

  @override
  void initState() {
    super.initState();
    if (!_isLiveCameraSupported()) {
      _hasError = true;
      _errorMsg = _unsupportedPlatformMessage();
      return;
    }
    _checkBackendAndInit();
  }

  bool _isLiveCameraSupported() {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _unsupportedPlatformMessage() {
    return 'Live camera is supported on Android, iOS, or Web (Chrome/Firefox).\n'
        'For desktop Linux, run web mode instead:\n'
        'flutter run -d chrome';
  }

  /// Check backend health, then initialize camera.
  Future<void> _checkBackendAndInit() async {
    setState(() => _checkingBackend = true);
    _backendReachable = await _backend.checkHealth();
    if (mounted) setState(() => _checkingBackend = false);
    await _initCamera(0);
  }

  Future<void> _initCamera(int index) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMsg = 'No camera found.';
        });
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
        _hasError = false;
        _cameraIndex = index % _cameras.length;
      });
      if (_backendReachable) {
        await _startStreaming();
      }
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = 'Camera error: ${e.description}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMsg = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _stopStreaming();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startStreaming() async {
    _stopStreaming();
    try {
      _channel = WebSocketChannel.connect(_backend.wsUri);
      _channel!.stream.listen(
        (data) {
          if (!mounted || data is! String) {
            _sending = false;
            return;
          }
          try {
            _handleWsPayload(data);
          } catch (_) {
          } finally {
            _sending = false;
          }
        },
        onError: (e) {
          if (mounted) {
            debugPrint('[LiveVideo] WebSocket error: $e');
            setState(() => _isStreaming = false);
          }
          _sending = false;
          _scheduleReconnect();
        },
        onDone: () {
          if (mounted) setState(() => _isStreaming = false);
          _sending = false;
          _scheduleReconnect();
        },
      );

      _frameTimer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _sendFrame(),
      );

      setState(() {
        _isStreaming = true;
        _reconnectAttempts = 0;
      });
    } catch (e) {
      debugPrint('[LiveVideo] Could not connect: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (mounted) {
        setState(() {
          _backendReachable = false;
          _isStreaming = false;
        });
      }
      return;
    }
    _reconnectAttempts++;
    Future.delayed(Duration(seconds: 2 * _reconnectAttempts), () {
      if (mounted && !_isStreaming) {
        _startStreaming();
      }
    });
  }

  void _stopStreaming() {
    _frameTimer?.cancel();
    _frameTimer = null;
    _sending = false;
    _isStreaming = false;
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _sendFrame() async {
    if (!_isInitialized || _controller == null || !_isStreaming || _sending)
      return;
    _sending = true;
    try {
      final frame = await _controller!.takePicture();
      final bytes = await frame.readAsBytes();
      final b64 = base64Encode(bytes);
      _channel?.sink.add('data:image/jpeg;base64,$b64');
    } catch (_) {
      _sending = false;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _handleWsPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        // Annotated frame
        final imageData = decoded['image']?.toString();
        if (imageData != null && imageData.isNotEmpty) {
          final b64 = imageData.contains(',')
              ? imageData.split(',').last
              : imageData;
          _processedFrame = base64Decode(b64);
        }

        // Face crop for unknown faces
        final faceCropData = decoded['face_crop']?.toString();
        if (faceCropData != null && faceCropData.isNotEmpty) {
          final fc = faceCropData.contains(',')
              ? faceCropData.split(',').last
              : faceCropData;
          _lastFaceCrop = base64Decode(fc);
        } else {
          _lastFaceCrop = null;
        }

        final isKnown = decoded['is_known'] as bool?;
        final label = decoded['label']?.toString();
        final name = decoded['name']?.toString();
        final distance = decoded['distance'] as num?;
        final riskDetected = decoded['risk_detected'] == true;
        final ownerInFrame = decoded['owner_in_frame'] == true;
        final isOwner = decoded['is_owner'] == true;

        // Build a more informative label
        String displayLabel;
        if (label != null) {
          displayLabel = label;
          if (isOwner) {
            displayLabel += ' (Owner)';
          }
        } else if (isKnown == null) {
          displayLabel = 'Waiting recognition...';
        } else {
          displayLabel = isKnown ? 'Known' : 'Unknown';
        }

        if (ownerInFrame && !riskDetected) {
          displayLabel += ' ✓ SAFE';
        } else if (riskDetected) {
          displayLabel += ' ⚠ RISK';
        }

        _recognitionLabel = displayLabel;
        _recognitionName = (name ?? '').trim();
        _recognitionDistance = distance?.toDouble();
        setState(() {});

        if ((isKnown == false ||
                _recognitionLabel.toLowerCase().contains('unknown')) &&
            _processedFrame != null) {
          _pushUnknownNotification();
        }
        if (riskDetected) {
          _showError('⚠️ Risk detected! Unknown person with dangerous object!');
        }
        return;
      }
    } catch (_) {}

    // Raw base64 fallback
    final b64 = payload.contains(',') ? payload.split(',').last : payload;
    final bytes = base64Decode(b64);
    setState(() => _processedFrame = bytes);
  }

  void _pushUnknownNotification() {
    final now = DateTime.now();
    if (_lastUnknownNotificationAt != null &&
        now.difference(_lastUnknownNotificationAt!) <
            const Duration(seconds: 8)) {
      return;
    }
    _lastUnknownNotificationAt = now;
    SecurityEventStore.instance.addUnknownEvent(
      imageBytes: _processedFrame,
      faceCropBytes: _lastFaceCrop,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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

            // Backend status banner
            _buildStatusBanner(),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: _buildCameraView(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: _buildProcessedPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNav(currentIndex: 1, user: widget.user),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (_checkingBackend) {
      return _statusContainer(
        icon: Icons.sync_rounded,
        text: 'Checking backend connection…',
        color: const Color(0xFFFF9800),
        spinning: true,
      );
    }
    if (!_backendReachable) {
      return _statusContainer(
        icon: Icons.cloud_off_rounded,
        text: 'Backend offline — camera-only mode',
        color: const Color(0xFFFF5722),
        action: GestureDetector(
          onTap: _checkBackendAndInit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    if (_isStreaming) {
      return const SizedBox.shrink(); // All good, hide banner
    }
    return const SizedBox.shrink();
  }

  Widget _statusContainer({
    required IconData icon,
    required String text,
    required Color color,
    bool spinning = false,
    Widget? action,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (spinning)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: color, strokeWidth: 2),
            )
          else
            Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (action != null) action,
        ],
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
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white24,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMsg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _isLiveCameraSupported() ? () => _initCamera(0) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.btnGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
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
                color: Color(0xFF6B8A9A),
                strokeWidth: 2.5,
              ),
              SizedBox(height: 16),
              Text(
                'Starting camera…',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
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
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isStreaming ? Colors.red : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isStreaming
                        ? 'LIVE'
                        : (_backendReachable ? 'CONNECTING' : 'CAMERA ONLY'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessedPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_processedFrame == null && !_backendReachable)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.white.withOpacity(0.15),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Backend offline',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Face processing unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            )
          else if (_processedFrame == null)
            const Center(
              child: Text(
                'Waiting processed frame',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.memory(
                _processedFrame!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Result: $_recognitionLabel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (_recognitionName.isNotEmpty)
                    Text(
                      'Name: $_recognitionName',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  if (_recognitionDistance != null)
                    Text(
                      'Distance: ${_recognitionDistance!.toStringAsFixed(3)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
