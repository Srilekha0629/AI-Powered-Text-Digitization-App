import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  File? _capturedImage;
  bool _showCamera = true;
  bool _isCapturing = false;
  bool _isProcessing = false;
  late AnimationController _animationController;
  List<CameraDescription> cameras = [];

  final double _scanFrameTopMargin = 120.0;
  final double _scanFrameWidth = 300.0;
  final double _scanFrameHeight = 400.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      await _initCamera();
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isEmpty) {
        if (mounted) setState(() => _showCamera = false);
        return;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.auto);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() => _showCamera = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize camera')),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      final file = File(image.path);
      await _processImage(file);
    } catch (e) {
      debugPrint("Capture failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _processImage(File imageFile) async {
    if (!mounted) return;
    
    setState(() {
      _isProcessing = true;
      _showCamera = false;
    });
    
    try {
      final processedFile = await _enhanceAndCropImage(imageFile);
      if (processedFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process image')),
          );
        }
        return;
      }

      // Save to prescription_images directory
      final appDir = await getApplicationDocumentsDirectory();
      final prescriptionDir = Directory('${appDir.path}/prescription_images');
      if (!await prescriptionDir.exists()) {
        await prescriptionDir.create(recursive: true);
      }
      final fileName = 'prescription_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await processedFile.copy('${prescriptionDir.path}/$fileName');

      if (!mounted) return;
      setState(() => _capturedImage = savedFile);

      if (mounted) {
        Navigator.pop(context); // Return to PrescriptionScanPage
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EMR saved successfully'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      debugPrint("Processing error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<File?> _enhanceAndCropImage(File originalImage) async {
    try {
      final bytes = await originalImage.readAsBytes();
      var capturedImage = img.decodeImage(bytes);
      if (capturedImage == null) return null;

      // Enhance image contrast and brightness
      capturedImage = img.adjustColor(
        capturedImage,
        brightness: 0.2,
        contrast: 1.2,
        gamma: 0.8,
      );

      // Convert to grayscale for better OCR
      capturedImage = img.grayscale(capturedImage);

      final deviceWidth = MediaQuery.of(context).size.width;
      final deviceHeight = MediaQuery.of(context).size.height;

      final frameLeft = (deviceWidth - _scanFrameWidth) / 2;
      final frameTop = _scanFrameTopMargin;

      final cropLeft = frameLeft / deviceWidth;
      final cropTop = frameTop / deviceHeight;
      final cropWidth = _scanFrameWidth / deviceWidth;
      final cropHeight = _scanFrameHeight / deviceHeight;

      final x = (cropLeft * capturedImage.width).round();
      final y = (cropTop * capturedImage.height).round();
      final width = (cropWidth * capturedImage.width).round();
      final height = (cropHeight * capturedImage.height).round();

      final safeWidth = x + width > capturedImage.width ? capturedImage.width - x : width;
      final safeHeight = y + height > capturedImage.height ? capturedImage.height - y : height;

      final croppedImage = img.copyCrop(
        capturedImage,
        x: x,
        y: y,
        width: safeWidth,
        height: safeHeight,
      );

      final tempDir = await Directory.systemTemp.createTemp();
      final croppedFile = File('${tempDir.path}/cropped_emr.jpg');
      await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));

      return croppedFile;
    } catch (e) {
      debugPrint("Image processing error: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_showCamera && _controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_controller!),
            ),
          if (_capturedImage != null)
            Positioned(
              top: _scanFrameTopMargin,
              left: (MediaQuery.of(context).size.width - _scanFrameWidth) / 2,
              child: SizedBox(
                width: _scanFrameWidth,
                height: _scanFrameHeight,
                child: Image.file(_capturedImage!, fit: BoxFit.fill),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Scan Prescription',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 15,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          if (_showCamera && !_isProcessing)
            Positioned(
              top: _scanFrameTopMargin,
              left: (MediaQuery.of(context).size.width - _scanFrameWidth) / 2,
              child: GestureDetector(
                onTap: _captureImage,
                child: Stack(
                  children: [
                    Container(
                      width: _scanFrameWidth,
                      height: _scanFrameHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.purple, width: 2),
                      ),
                      child: Stack(
                        children: [
                          // Corner decorations
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.purple, width: 4),
                                  top: BorderSide(color: Colors.purple, width: 4),
                                ),
                              ),
                            ),
                          ),
                          // Top-right corner
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.purple, width: 4),
                                  top: BorderSide(color: Colors.purple, width: 4),
                                ),
                              ),
                            ),
                          ),
                          // Bottom-left corner
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Colors.purple, width: 4),
                                  bottom: BorderSide(color: Colors.purple, width: 4),
                                ),
                              ),
                            ),
                          ),
                          // Bottom-right corner
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.purple, width: 4),
                                  bottom: BorderSide(color: Colors.purple, width: 4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Tap to capture',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

enum Corner { topLeft, topRight, bottomLeft, bottomRight }

class CornerPainter extends CustomPainter {
  final Corner corner;
  final Color color;
  final double strokeWidth;
  final double animationValue;

  CornerPainter({
    required this.corner,
    this.color = Colors.deepPurple,
    this.strokeWidth = 4.0,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final cornerSize = 30.0 * animationValue;
    final path = Path();

    switch (corner) {
      case Corner.topLeft:
        path.moveTo(0, cornerSize);
        path.lineTo(0, 0);
        path.lineTo(cornerSize, 0);
        break;
      case Corner.topRight:
        path.moveTo(size.width - cornerSize, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, cornerSize);
        break;
      case Corner.bottomLeft:
        path.moveTo(0, size.height - cornerSize);
        path.lineTo(0, size.height);
        path.lineTo(cornerSize, size.height);
        break;
      case Corner.bottomRight:
        path.moveTo(size.width - cornerSize, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, size.height - cornerSize);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
} 