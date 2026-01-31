import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _isScanning = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _scanFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // 使用MobileScanner分析图片中的二维码
        final capture = await controller.analyzeImage(image.path);
        if (capture != null &&
            capture.barcodes.isNotEmpty &&
            capture.barcodes.first.rawValue != null) {
          if (mounted) {
            Navigator.pop(context, capture.barcodes.first.rawValue);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('未检测到二维码')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码导入配置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _scanFromGallery,
            tooltip: '从相册选择',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_isScanning) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    _isScanning = false; // 防止重复扫描
                    Navigator.pop(context, barcodes.first.rawValue);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
