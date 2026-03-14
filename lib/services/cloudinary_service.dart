import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "dzdgugvbbr";
  static const String uploadPreset = "zullo_upload";

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
      );

      final request = http.MultipartRequest("POST", url);
      request.fields["upload_preset"] = uploadPreset;

      request.files.add(
        await http.MultipartFile.fromPath("file", imageFile.path),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      print("CLOUDINARY STATUS: ${response.statusCode}");
      print("CLOUDINARY BODY: $responseData");

      final decoded = jsonDecode(responseData);

      if (response.statusCode == 200) {
        return decoded["secure_url"];
      }

      return null;
    } catch (e) {
      print("CLOUDINARY ERROR: $e");
      return null;
    }
  }
}