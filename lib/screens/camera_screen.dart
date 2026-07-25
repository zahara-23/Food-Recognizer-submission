import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/food_prediction.dart';
import '../services/classifier_service.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/state_views.dart';

/// Kamera kustom (bukan bawaan OS) menggunakan package `camera`.
/// Mendukung dua mode:
///  - Real-time: klasifikasi berjalan terus-menerus dari camera feed (stream).
///  - Foto biasa: ambil satu gambar untuk diproses di ResultScreen.
///
/// Kriteria 1 (Advanced): "fitur identifikasi gambar dengan camera stream
/// atau camera feed dengan library camera."
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  bool _isInitializing = true;
  String? _errorMessage;

  bool _isLiveMode = false;
  bool _isProcessingFrame = false;
  FoodPrediction? _livePrediction;
  DateTime _lastInferenceAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const _minInferenceInterval = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _errorMessage = 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan aplikasi.';
        _isInitializing = false;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang tersedia pada perangkat ini.');
      }

      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal menginisialisasi kamera: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _toggleLiveMode() async {
    if (_controller == null) return;

    if (_isLiveMode) {
      await _controller!.stopImageStream();
      setState(() {
        _isLiveMode = false;
        _livePrediction = null;
      });
    } else {
      setState(() => _isLiveMode = true);
      await _controller!.startImageStream(_onCameraFrame);
    }
  }

  void _onCameraFrame(CameraImage image) {
    if (_isProcessingFrame) return;
    final now = DateTime.now();
    if (now.difference(_lastInferenceAt) < _minInferenceInterval) return;

    _isProcessingFrame = true;
    _lastInferenceAt = now;

    ClassifierService.instance.classifyCameraImage(image).then((prediction) {
      if (mounted) setState(() => _livePrediction = prediction);
    }).catchError((_) {
      // Abaikan error per-frame supaya stream tetap berjalan mulus.
    }).whenComplete(() {
      _isProcessingFrame = false;
    });
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || _controller!.value.isTakingPicture) return;

    try {
      if (_isLiveMode) {
        await _controller!.stopImageStream();
      }
      final file = await _controller!.takePicture();
      if (mounted) Navigator.of(context).pop(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil foto: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Kamera'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_controller != null)
            IconButton(
              icon: Icon(_isLiveMode ? Icons.pause_circle_outline : Icons.play_circle_outline),
              tooltip: _isLiveMode ? 'Hentikan mode real-time' : 'Mulai mode real-time',
              onPressed: _toggleLiveMode,
            ),
        ],
      ),
      body: _isInitializing
          ? const LoadingView(message: 'Menyiapkan kamera...')
          : _errorMessage != null
              ? ErrorView(message: _errorMessage!, onRetry: _setupCamera)
              : _buildCameraPreview(),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        if (_isLiveMode && _livePrediction != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _livePrediction!.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConfidenceBadge(confidence: _livePrediction!.confidence),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white54, width: 4),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.black87),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
