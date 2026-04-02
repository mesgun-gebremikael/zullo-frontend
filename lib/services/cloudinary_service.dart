import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "dzdugvbbr";
  static const String uploadPreset = "zullo_upload";

  static Future<String?> uploadImage(File imageFile) async {
  try {
    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    print("CLOUDINARY URL: $url");
    print("CLOUDINARY PRESET: $uploadPreset");
    print("CLOUDINARY FILE PATH: ${imageFile.path}");


    final request = http.MultipartRequest("POST", url);
    request.fields["upload_preset"] = uploadPreset;
    request.fields["folder"] = "zullo_profiles";

    request.files.add(
      await http.MultipartFile.fromPath("file", imageFile.path),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    print("CLOUDINARY STATUS: ${response.statusCode}");
    print("CLOUDINARY BODY: $responseData");

    final decoded = jsonDecode(responseData);

    if (response.statusCode == 200) {
      final secureUrl = decoded["secure_url"]?.toString();
      if (secureUrl == null || secureUrl.isEmpty) return null;

      return _optimizedImageUrl(secureUrl);
    }

    return null;
  } catch (e) {
    print("CLOUDINARY ERROR: $e");
    return null;
  }
}

static String _optimizedImageUrl(String url) {
  return url.replaceFirst(
    '/upload/',
    '/upload/f_auto,q_auto,w_1080,c_limit/',
  );
}
}