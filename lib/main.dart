import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import  'splash.dart';
import 'package:path_provider/path_provider.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

List<CameraDescription> cameras = [];
Map<String, Map<String, dynamic>> emrRecords = {};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  try {
    cameras = await availableCameras();
    await loadSavedEMRs();
  } catch (e) {
    debugPrint('Init Error: $e');
  }
  runApp(const MyApp());
}

Future<void> loadSavedEMRs() async {
  final prefs = await SharedPreferences.getInstance();
  final String? jsonData = prefs.getString('emr_records');
  if (jsonData != null) {
    try {
      final Map<String, dynamic> raw = json.decode(jsonData);
      emrRecords = raw.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value)));
    } catch (e) {
      debugPrint('Error loading EMR records: $e');
    }
  }
}

Future<void> saveEMRRecords() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('emr_records', json.encode(emrRecords));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EMR Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SplashScreen(),
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
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;

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
    _initCamera();
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

      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final inputImage = InputImage.fromFile(savedFile);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        final rawText = recognizedText.text;

        if (rawText.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No text found in the scanned area')),
            );
          }
          return;
        }

        final uri = Uri.parse('http://192.168.83.136:3000/emr');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'rawText': rawText}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 201) {
          final data = json.decode(response.body);
          final emr = data['emr'] as Map<String, dynamic>? ?? {};

          final patientId = data['patient_id']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
          final timestamp = emr['timestamp']?.toString() ?? DateTime.now().toIso8601String();
          
          DateTime? parsedDate;
          try {
            parsedDate = DateTime.parse(timestamp);
          } catch (e) {
            debugPrint('Date parsing error: $e');
            parsedDate = DateTime.now();
          }
          
          final formattedDate = DateFormat('dd-MM-yyyy').format(parsedDate);

          final newRecord = {
            'patientId': patientId,
            'date': formattedDate,
            'name': emr['patient_name']?.toString() ?? 'Unknown Patient',
            'age': emr['age']?.toString() ?? 'Unknown',
            'gender': emr['gender']?.toString() ?? 'Unknown',
            'diagnosis': emr['diagnosis']?.toString() ?? 'No diagnosis provided',
            'prescriptions': (emr['prescriptions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          };

          emrRecords[patientId] = newRecord;
          await saveEMRRecords();

          if (mounted) {
            Navigator.pop(context); // Return to PrescriptionScanPage
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('EMR saved successfully'),
                backgroundColor: Colors.purple,
              ),
            );
          }
        } else {
          debugPrint("Server error: ${response.statusCode}");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Server error: ${response.statusCode}')),
            );
          }
        }
      } finally {
        textRecognizer.close();
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

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        await _processImage(File(pickedFile.path));
      }
    } catch (e) {
      debugPrint("Gallery error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image from gallery')),
        );
      }
    }
  }

  Future<void> _retakePhoto() async {
    if (!mounted) return;
    setState(() {
      _capturedImage = null;
      _showCamera = true;
      _isProcessing = false;
    });
    await _initCamera();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildBottomButton(IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 30),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_showCamera && _controller != null && _controller!.value.isInitialized)
            Positioned.fill(
              child: CameraPreview(_controller!),
            )
          else if (_capturedImage != null)
            Positioned(
              top: _scanFrameTopMargin,
              left: (MediaQuery.of(context).size.width - _scanFrameWidth) / 2,
              child: Container(
                width: _scanFrameWidth,
                height: _scanFrameHeight,
                child: Image.file(_capturedImage!, fit: BoxFit.fill),
              ),
            ),

          // Scanner overlay with improved visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(0, 0, 0, 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Color.fromRGBO(0, 0, 0, 0.7),
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: _scanFrameTopMargin),
                  Container(
                    width: _scanFrameWidth,
                    height: _scanFrameHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Color.fromRGBO(255, 255, 255, 0.3), width: 2),
                      borderRadius: BorderRadius.circular(10),
                      color: Color.fromRGBO(0, 0, 0, 0.2),
                    ),
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              child: CustomPaint(
                                size: const Size(50, 50),
                                painter: CornerPainter(
                                  corner: Corner.topLeft,
                                  animationValue: _animationController.value,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: CustomPaint(
                                size: const Size(50, 50),
                                painter: CornerPainter(
                                  corner: Corner.topRight,
                                  animationValue: _animationController.value,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: CustomPaint(
                                size: const Size(50, 50),
                                painter: CornerPainter(
                                  corner: Corner.bottomLeft,
                                  animationValue: _animationController.value,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CustomPaint(
                                size: const Size(50, 50),
                                painter: CornerPainter(
                                  corner: Corner.bottomRight,
                                  animationValue: _animationController.value,
                                ),
                              ),
                            ),
                            Center(child: Container()),
                          ],
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'EMR Scanner',
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.deepPurple.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isProcessing)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Processing EMR...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),

          if (_showCamera && !_isProcessing)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _captureImage,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomButton(Icons.photo_library, 'Gallery', _pickImageFromGallery),
                _buildBottomButton(Icons.refresh, 'Retake', _retakePhoto),
                _buildBottomButton(Icons.folder_open, 'Records', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EMRRecordsPage()),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EMRForm extends StatelessWidget {
  final String patientId, date, name, age, gender, diagnosis;
  final List<String> prescriptions;

  const EMRForm({
    super.key,
    required this.patientId,
    required this.date,
    required this.name,
    required this.age,
    required this.gender,
    required this.diagnosis,
    required this.prescriptions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf2f2f2),
      appBar: AppBar(
        title: const Text('EMR Details'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopTitle(),
                        const SizedBox(height: 20),
                        _buildDivider(),
                        const SizedBox(height: 10),
                        _buildTextField('Patient ID', patientId),
                        const SizedBox(height: 15),
                        _buildTextField('Date', date),
                        const SizedBox(height: 20),
                        _buildTextField('Name', name),
                        const SizedBox(height: 15),
                        _buildTextField('Age', age),
                        const SizedBox(height: 15),
                        _buildTextField('Gender', gender),
                        const SizedBox(height: 25),
                        _buildDivider(),
                        const SizedBox(height: 10),
                        _buildLabel('Diagnosis'),
                        const SizedBox(height: 8),
                        _buildBox(diagnosis),
                        const SizedBox(height: 20),
                        _buildLabel('Prescriptions'),
                        const SizedBox(height: 8),
                        _buildBox(prescriptions.join(', ')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTitle() => Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EMR RECORD',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                'Generated on ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      );

  Widget _buildDivider() => const Divider(thickness: 2, color: Colors.deepPurpleAccent);

  Widget _buildTextField(String label, String value) {
    return TextField(
      controller: TextEditingController(text: value),
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      readOnly: true,
    );
  }

  Widget _buildLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.deepPurple,
        ),
      );

  Widget _buildBox(String content) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey),
        ),
        child: Text(
          content,
          style: const TextStyle(fontSize: 16),
        ),
      );
}

class EMRRecordsPage extends StatefulWidget {
  const EMRRecordsPage({super.key});
  @override
  State<EMRRecordsPage> createState() => _EMRRecordsPageState();
}

class _EMRRecordsPageState extends State<EMRRecordsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredRecords = emrRecords.values.where((record) {
      final name = record['name']?.toString().toLowerCase() ?? '';
      final id = record['patientId']?.toString().toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("EMR Records"),
        backgroundColor: Colors.deepPurple,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or ID...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: filteredRecords.isEmpty
          ? const Center(
              child: Text(
                "No records found",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: filteredRecords.length,
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(103, 58, 183, 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_copy, color: Colors.deepPurple),
                    ),
                    title: Text(
                      record['name']?.toString() ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "ID: ${record['patientId']} • Date: ${record['date']}",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EMRForm(
                            patientId: record['patientId']?.toString() ?? 'unknown',
                            date: record['date']?.toString() ?? 'Unknown date',
                            name: record['name']?.toString() ?? 'Unknown',
                            age: record['age']?.toString() ?? 'Unknown',
                            gender: record['gender']?.toString() ?? 'Unknown',
                            diagnosis: record['diagnosis']?.toString() ?? 'No diagnosis',
                            prescriptions: List<String>.from(record['prescriptions'] ?? []),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}