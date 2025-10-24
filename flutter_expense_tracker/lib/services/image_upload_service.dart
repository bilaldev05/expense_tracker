import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class UploadService {
  static Future<void> uploadBill(File imageFile) async {
    final uri = Uri.parse("http://10.0.2.2:8000/upload-bill");

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: basename(imageFile.path),
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print("✅ Success: ${response.body}");
      } else {
        print("❌ Error: ${response.statusCode} => ${response.body}");
      }
    } catch (e) {
      print("🚫 Upload error: $e");
    }
  }
}
