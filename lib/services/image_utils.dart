import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;

import '../core/constants.dart';

/// Kumpulan helper untuk mengonversi & menyiapkan gambar sebelum
/// dimasukkan ke model TFLite (LiteRT).
class ImageUtils {
  ImageUtils._();

  /// Membaca gambar statis (hasil image_picker / image_cropper) dari [imagePath]
  /// menjadi objek `image_lib.Image`.
  static Future<image_lib.Image?> decodeStaticImage(String imagePath) async {
    final img = await image_lib.decodeImageFile(imagePath);
    return img;
  }

  /// Mengonversi `CameraImage` (format YUV420 dari camera feed / stream)
  /// menjadi objek `image_lib.Image` agar bisa diproses sama seperti
  /// gambar statis. Dipanggil setiap frame ketika mode real-time aktif.
  static image_lib.Image convertCameraImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final output = image_lib.Image(width: width, height: height);

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        final yIndex = row * yRowStride + col;
        final uvRow = row ~/ 2;
        final uvCol = col ~/ 2;
        final uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride;

        final y = yPlane.bytes[yIndex];
        final u = uPlane.bytes[uvIndex];
        final v = vPlane.bytes[uvIndex];

        // Konversi YUV -> RGB (BT.601)
        final yValue = y.toDouble();
        final uValue = u.toDouble() - 128.0;
        final vValue = v.toDouble() - 128.0;

        int r = (yValue + 1.370705 * vValue).round();
        int g = (yValue - 0.337633 * uValue - 0.698001 * vValue).round();
        int b = (yValue + 1.732446 * uValue).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        output.setPixelRgb(col, row, r, g, b);
      }
    }

    return output;
  }

  /// Resize ke ukuran input model ([AppConstants.inputImageSize]) dan
  /// susun menjadi buffer `Uint8List` datar RGB (H x W x 3), sesuai
  /// kebutuhan tensor input UINT8 model food classifier.
  static Uint8List imageToByteListUint8(image_lib.Image srcImage) {
    final size = AppConstants.inputImageSize;
    final resized = image_lib.copyResize(
      srcImage,
      width: size,
      height: size,
      interpolation: image_lib.Interpolation.linear,
    );

    final bytes = Uint8List(size * size * 3);
    int pixelIndex = 0;
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final pixel = resized.getPixel(x, y);
        bytes[pixelIndex++] = pixel.r.toInt();
        bytes[pixelIndex++] = pixel.g.toInt();
        bytes[pixelIndex++] = pixel.b.toInt();
      }
    }
    return bytes;
  }

  /// Menyimpan `image_lib.Image` sementara ke direktori temp sebagai JPEG,
  /// berguna untuk menampilkan hasil crop/preview di layar hasil.
  static Future<File> saveTempJpeg(image_lib.Image img, String path) async {
    final jpg = image_lib.encodeJpg(img, quality: 90);
    final file = File(path);
    await file.writeAsBytes(jpg);
    return file;
  }
}
