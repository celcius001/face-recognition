import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image/image.dart' as img;

enum DetectionStatus { noFace, fail, success }

class TestApp extends StatefulWidget {
  const TestApp({super.key});

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  @override
  Widget build(BuildContext context) {
    return const CameraScreen();
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  late WebSocketChannel channel;
  DetectionStatus? status;

  String get currentStatus {
    if (status == null) {
      return "Initailizing";
    }
    switch (status!) {
      case DetectionStatus.noFace:
        return "No Face Detected";
      case DetectionStatus.fail:
        return "Unrecognized Face Detected";
      case DetectionStatus.success:
        return "Face Detected";
    }
  }

  Color get currentStatusColor {
    if (status == null) {
      return Colors.grey;
    }
    switch (status!) {
      case DetectionStatus.noFace:
        return Colors.grey;
      case DetectionStatus.fail:
        return Colors.red;
      case DetectionStatus.success:
        return Colors.greenAccent;
    }
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();
    initializeWebSocket();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras[1];

    controller = CameraController(firstCamera, ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420, enableAudio: false);

    await controller!.initialize();
    setState(() {});
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final image = await controller!.takePicture();
        final compressImageBytes = compressImage(image.path);
        channel.sink.add(compressImageBytes);
      } catch (_) {}
    });
  }

  void initializeWebSocket() {
    String uri =
        "ws://192.168.0.107:8785"; // TODO: python server address - change this
    channel = IOWebSocketChannel.connect(uri);
    channel.stream.listen((dynamic data) {
      debugPrint(data);
      data = jsonDecode(data);
      if (data['data'] == null) {
        debugPrint('Server error occured in recognizing face');
        return;
      }
      switch (data['data']) {
        case 0:
          status = DetectionStatus.noFace;
          break;
        case 1:
          status = DetectionStatus.fail;
          break;
        case 2:
          status = DetectionStatus.success;
          break;
        default:
          status = DetectionStatus.noFace;
          break;
      }
    }, onError: (dynamic error) {
      debugPrint(error);
    }, onDone: () {
      debugPrint('WebSocket Connection Closed');
    });
  }

  Uint8List compressImage(String imagePath, {int quality = 85}) {
    final image =
        img.decodeImage(Uint8List.fromList(File(imagePath).readAsBytesSync()));
    final compressImage = img.encodeJpg(image!, quality: quality);
    debugPrint(compressImage.toString());
    return compressImage;
  }

  @override
  void dispose() {
    controller?.dispose();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(controller?.value.isInitialized ?? false)) {
      return const SizedBox();
    }

    return Stack(
      children: [
        Positioned.fill(
            child: AspectRatio(
          aspectRatio: controller!.value.aspectRatio,
          child: CameraPreview(controller!),
        )),
        Align(
          alignment: const Alignment(0, 0.85),
          child: ElevatedButton(
              onPressed: () {},
              child: Text(
                currentStatus,
                style: const TextStyle(fontSize: 20),
              )),
        )
      ],
    );
  }
}
