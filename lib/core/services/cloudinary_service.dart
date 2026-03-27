import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) => CloudinaryService());

class CloudinaryService {
  final String cloudName = "dceh4ob2i";
  final String apiKey = "256641331991177";
  final String apiSecret = "eNzBz9AxS9d_VF2ebvSoAth18s0";

  final Dio _dio = Dio();

  Future<String> uploadImage(String filePath, {String folder = "profile_photos"}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final paramsToSign = "folder=$folder&timestamp=$timestamp$apiSecret";
    final signature = _generateSignature(paramsToSign);

    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
      "api_key": apiKey,
      "timestamp": timestamp,
      "signature": signature,
      "folder": folder,
    });

    try {
      final response = await _dio.post(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
        data: formData,
      );
      return response.data["secure_url"];
    } catch (e) {
      throw Exception("Cloudinary image upload error: $e");
    }
  }

  Future<String> uploadRaw(String filePath, {String folder = "gifts/animations"}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final paramsToSign = "folder=$folder&timestamp=$timestamp$apiSecret";
    final signature = _generateSignature(paramsToSign);

    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(filePath),
      "api_key": apiKey,
      "timestamp": timestamp,
      "signature": signature,
      "folder": folder,
    });

    try {
      final response = await _dio.post(
        "https://api.cloudinary.com/v1_1/$cloudName/raw/upload",
        data: formData,
      );
      return response.data["secure_url"];
    } catch (e) {
      throw Exception("Cloudinary raw upload error: $e");
    }
  }

  String _generateSignature(String paramsToSign) {
    return sha1.convert(utf8.encode(paramsToSign)).toString();
  }
}
