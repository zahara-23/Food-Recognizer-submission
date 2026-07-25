import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

/// Pesan permintaan inferensi yang dikirim ke isolate background.
class _InferenceRequest {
  final int id;
  final Uint8List inputBytes;
  final SendPort replyPort;

  _InferenceRequest(this.id, this.inputBytes, this.replyPort);
}

/// Pesan hasil inferensi yang dikirim balik dari isolate background.
class InferenceResult {
  final int id;
  final List<int> outputQuantized; // nilai UINT8 mentah, len = jumlah kelas
  final String? error;

  InferenceResult(this.id, this.outputQuantized, {this.error});
}

/// Argumen yang dikirim saat pertama kali men-spawn isolate.
class _IsolateInitArgs {
  final SendPort mainSendPort;
  final String modelPath;
  final int inputSize;
  final int numThreads;

  _IsolateInitArgs(
    this.mainSendPort,
    this.modelPath,
    this.inputSize,
    this.numThreads,
  );
}

/// Membungkus interpreter TFLite yang berjalan sepenuhnya di background
/// isolate, supaya proses inferensi (yang cukup berat) tidak membuat
/// UI utama freeze/jank saat model memproses gambar.
///
/// Kriteria 2 (Skilled): "Menggunakan Isolate untuk menjalankan proses
/// inferensi dalam background thread."
class ClassifierIsolate {
  final Isolate _isolate;
  final SendPort _sendPort;
  final ReceivePort _receivePort = ReceivePort();

  int _requestIdCounter = 0;
  final Map<int, Completer<InferenceResult>> _pending = {};

  ClassifierIsolate._(this._isolate, this._sendPort) {
    _receivePort.listen((message) {
      if (message is InferenceResult) {
        final completer = _pending.remove(message.id);
        completer?.complete(message);
      }
    });
  }

  static Future<ClassifierIsolate> spawn({
    required String modelPath,
    required int inputSize,
    int numThreads = 4,
  }) async {
    final initPort = ReceivePort();
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      _IsolateInitArgs(initPort.sendPort, modelPath, inputSize, numThreads),
    );

    // Isolate akan mengirim SendPort miliknya sendiri begitu ia siap menerima perintah.
    final workerSendPort = await initPort.first as SendPort;
    return ClassifierIsolate._(isolate, workerSendPort);
  }

  /// Mengirim satu gambar (buffer RGB uint8 yang sudah di-resize) untuk
  /// diklasifikasikan. Berjalan penuh di background isolate sehingga
  /// tidak memblokir frame rendering UI.
  Future<InferenceResult> classify(Uint8List inputBytes) async {
    final id = _requestIdCounter++;
    final completer = Completer<InferenceResult>();
    _pending[id] = completer;

    _sendPort.send(_InferenceRequest(id, inputBytes, _receivePort.sendPort));
    return completer.future;
  }

  void dispose() {
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  /// Entry point isolate baru. Interpreter di-load sekali di sini dan
  /// dipakai berulang kali selama isolate hidup (efisien untuk mode
  /// real-time / camera feed yang mengirim banyak frame per detik).
  static void _isolateEntryPoint(_IsolateInitArgs args) async {
    final commandPort = ReceivePort();
    args.mainSendPort.send(commandPort.sendPort);

    Interpreter? interpreter;
    int outputSize = 2024;
    try {
      final options = InterpreterOptions()..threads = args.numThreads;
      interpreter = Interpreter.fromFile(File(args.modelPath), options: options);
      interpreter.allocateTensors();
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (outputShape.length > 1) {
        outputSize = outputShape[1];
      }
    } catch (_) {
      interpreter = null;
    }

    await for (final message in commandPort) {
      if (message is! _InferenceRequest) continue;

      if (interpreter == null) {
        message.replyPort.send(
          InferenceResult(message.id, const [], error: 'Interpreter gagal dimuat'),
        );
        continue;
      }

      try {
        final input = message.inputBytes.reshape([1, args.inputSize, args.inputSize, 3]);
        final output = List.filled(outputSize, 0).reshape([1, outputSize]);

        interpreter.run(input, output);

        final flatOutput = (output[0] as List).cast<int>();
        message.replyPort.send(InferenceResult(message.id, flatOutput));
      } catch (e) {
        message.replyPort.send(InferenceResult(message.id, const [], error: e.toString()));
      }
    }
  }
}
