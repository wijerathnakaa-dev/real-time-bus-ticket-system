import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class NumberPlateOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _picker = ImagePicker();

  // Pattern matching Sri Lankan number plates: e.g. "WP ND-1024", "NC WP-4521", "ND-1024", "1024"
  final RegExp _plateRegex = RegExp(
    r'([A-Z]{2}[-\s]?[A-Z]{2,3}[-\s]?\d{4})|([A-Z]{2,3}[-\s]?\d{4})|(\b\d{2,3}[-\s]?\d{4}\b)',
    caseSensitive: false,
  );

  /// Captures a photo using device camera or gallery, performs OCR, and returns the extracted plate number.
  Future<String?> captureAndRecognizePlate({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (photo == null) return null;

      final inputImage = InputImage.fromFilePath(photo.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Search all blocks and lines strictly for standard vehicle plate regex patterns
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final cleanLine = line.text.trim().toUpperCase();
          final match = _plateRegex.firstMatch(cleanLine);
          if (match != null) {
            return _normalizePlate(match.group(0)!);
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('OCR plate recognition error: $e');
      return null;
    }
  }

  String _normalizePlate(String raw) {
    return raw.replaceAll(' ', '-').replaceAll('--', '-').toUpperCase();
  }

  void dispose() {
    _textRecognizer.close();
  }
}
