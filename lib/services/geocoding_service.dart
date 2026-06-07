import 'dart:convert';
import 'package:http/http.dart' as http;

/// 地理编码结果
class GeocodingResult {
  final double latitude;
  final double longitude;
  final String displayName;

  GeocodingResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });
}

/// 地理编码服务
///
/// 使用 OpenStreetMap Nominatim API（免费，无需 API Key）
/// 实现：
/// - 地址搜索 -> 经纬度 (forward geocoding)
/// - 经纬度 -> 地址 (reverse geocoding)
///
/// 注意：Nominatim 使用政策要求：
/// - 每个请求携带 User-Agent
/// - 每秒最多 1 个请求（本服务已内置延迟）
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'FastCheckApp/1.0';

  /// 上一次请求时间（用于限速）
  static DateTime _lastRequestTime = DateTime.now();

  /// 搜索地址，返回地理编码结果列表
  ///
  /// [query] 搜索关键词，如 "北京市朝阳区"
  /// [limit] 返回结果数量上限
  static Future<List<GeocodingResult>> searchAddress(
    String query, {
    int limit = 5,
  }) async {
    if (query.trim().isEmpty) return [];

    await _rateLimit();

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': limit.toString(),
      'accept-language': 'zh',
    });

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) {
        throw Exception('Geocoding API error: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      return data.map((item) {
        final map = item as Map<String, dynamic>;
        return GeocodingResult(
          latitude: double.parse(map['lat'] as String),
          longitude: double.parse(map['lon'] as String),
          displayName: map['display_name'] as String? ?? query,
        );
      }).toList();
    } catch (e) {
      throw Exception('搜索地址失败: $e');
    }
  }

  /// 根据经纬度反向查找地址
  static Future<GeocodingResult?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    await _rateLimit();

    final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'addressdetails': '1',
      'accept-language': 'zh',
    });

    try {
      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data =
          json.decode(response.body) as Map<String, dynamic>;

      return GeocodingResult(
        latitude: latitude,
        longitude: longitude,
        displayName: data['display_name'] as String? ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  /// 限速：确保请求间隔至少 1 秒
  static Future<void> _rateLimit() async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRequestTime).inMilliseconds;
    if (elapsed < 1100) {
      await Future.delayed(Duration(milliseconds: 1100 - elapsed));
    }
    _lastRequestTime = DateTime.now();
  }
}
