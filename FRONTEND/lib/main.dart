import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const SecureImageApp());
}

class SecureImageApp extends StatelessWidget {
  const SecureImageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Image Authentication',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  File? _image;
  String? _securedImagePath;
  String? _authenticatedImageB64;
  String _status = "No action yet.";
  final List<String> _logs = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _securedImagePath = null;
        _authenticatedImageB64 = null;
        _status = "Ready to secure or authenticate.";
        _logs.insert(0, "Selected: ${pickedFile.name}");
      });
    }
  }

  Future<void> _processImage(String endpoint) async {
    if (_image == null) return;
    setState(() => _status = "Processing...");

    final uri = Uri.parse("http://127.0.0.1:8000/$endpoint?preserve=true");

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', _image!.path));

    try {
      final response = await request.send();
      if (response.statusCode != 200) {
        setState(() => _status = "Error: ${response.statusCode}");
        _logs.insert(0, "Error ${response.statusCode} from $endpoint");
        return;
      }

      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        setState(() {
          _status = data['message'] ?? 'Done';
          _authenticatedImageB64 = data['restored_image_b64'];
          _securedImagePath = null; // ✅ Clear secured preview
          _logs.insert(
            0,
            "Authentication: ${data['message']} (${data['authentication_percentage']}%)",
          );
        });
      } else {
        final bytes = await response.stream.toBytes();

        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Secured Image',
          fileName: 'secured_image.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );

        if (outputPath == null) {
          setState(() {
            _status = "Save cancelled.";
            _logs.insert(0, "User cancelled save.");
          });
          return;
        }

        final outFile = File(outputPath);
        await outFile.writeAsBytes(bytes);

        setState(() {
          _securedImagePath = outFile.path;
          _authenticatedImageB64 = null; // ✅ Clear authenticated preview
          _status = "Secured image saved & preview updated.";
          _logs.insert(0, "Saved: ${outFile.path}");
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved successfully: ${outFile.path}'),
              backgroundColor: Colors.blueAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _status = "Network error: $e");
      _logs.insert(0, "Network error: $e");
    }
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFdbeafe), Color(0xFFeff6ff), Color(0xFFf0f9ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blueAccent.shade200.withOpacity(0.9),
          title: const Text("🔒 Secure Image — Authentication",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildLeftColumn()),
                        const SizedBox(width: 18),
                        Expanded(flex: 3, child: _buildMiddleColumn()),
                        const SizedBox(width: 18),
                        Expanded(flex: 2, child: _buildRightColumn()),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildLeftColumn(),
                          const SizedBox(height: 18),
                          _buildMiddleColumn(),
                          const SizedBox(height: 18),
                          _buildRightColumn(),
                        ],
                      ),
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return _buildCard(
      title: "Upload Image",
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                color: Colors.blue.shade50,
              ),
              child: Center(
                child: _image == null
                    ? const Text("Tap to select image",
                        style: TextStyle(color: Colors.black54))
                    : Image.file(_image!, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_image != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _processImage("secure"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Secure"),
                ),
                ElevatedButton(
                  onPressed: () => _processImage("authenticate"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    side: BorderSide(color: Colors.blueAccent.shade100),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Authenticate"),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_securedImagePath != null || _authenticatedImageB64 != null)
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text("Upload Another Image"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent.shade100,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiddleColumn() {
    return _buildCard(
      title: "Secured / Authenticated Preview",
      child: Column(
        children: [
          if (_securedImagePath != null)
            Image.file(File(_securedImagePath!), fit: BoxFit.contain)
          else if (_authenticatedImageB64 != null)
            Image.memory(base64Decode(_authenticatedImageB64!))
          else
            const Text("No secured or authenticated image yet",
                style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return _buildCard(
      title: "Activity Logs",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_status,
              style: const TextStyle(
                  fontSize: 15, color: Colors.black, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            height: 180,
            child: ListView.builder(
              reverse: true,
              itemCount: _logs.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Text("• ${_logs[i]}",
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87, height: 1.4)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_logs.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _logs.clear();
                    _status = "Logs cleared.";
                  });
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text("Clear Logs"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
