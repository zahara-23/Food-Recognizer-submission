import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../services/classifier_service.dart';
import '../widgets/state_views.dart';
import 'camera_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isModelLoading = true;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    setState(() {
      _isModelLoading = true;
      _modelError = null;
    });
    try {
      await ClassifierService.instance.initialize();
    } catch (e) {
      _modelError = 'Gagal memuat model: $e';
    } finally {
      if (mounted) setState(() => _isModelLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;
      await _cropAndProceed(picked.path);
    } catch (e) {
      _showSnackBar('Gagal mengambil gambar: $e');
    }
  }

  /// Kriteria 1 (Skilled): fitur crop dengan package image_cropper.
  Future<void> _cropAndProceed(String imagePath) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: imagePath,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Sesuaikan Gambar',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Sesuaikan Gambar'),
        ],
      );

      final finalPath = cropped?.path ?? imagePath;
      _goToResult(File(finalPath));
    } catch (e) {
      // Bila crop gagal/dibatalkan, tetap lanjutkan dengan gambar asli.
      _goToResult(File(imagePath));
    }
  }

  void _goToResult(File imageFile) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(imageFile: imageFile)),
    );
  }

  Future<void> _openLiveCamera() async {
    final capturedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (capturedPath != null) {
      await _cropAndProceed(capturedPath);
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Recognizer')),
      body: SafeArea(
        child: _isModelLoading
            ? const LoadingView(message: 'Menyiapkan model klasifikasi makanan...')
            : _modelError != null
                ? ErrorView(message: _modelError!, onRetry: _initModel)
                : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ramen_dining, size: 96, color: AppTheme.primary.withOpacity(0.85)),
          const SizedBox(height: 16),
          const Text(
            'Kenali makanan apa saja hanya\ndengan sekali jepret!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Ambil Foto dengan Kamera'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pilih dari Galeri'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openLiveCamera,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Identifikasi Real-time (Camera Feed)'),
            ),
          ),
        ],
      ),
    );
  }
}
