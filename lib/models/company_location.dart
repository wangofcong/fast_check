/// 公司地点模型
///
/// 对应数据库表 `company_locations`
/// 存储公司地址、经纬度坐标及地理围栏配置
class CompanyLocation {
  final int? id;
  final String name; // 地点名称，如 "公司总部"
  final String? address; // 详细地址
  final double latitude; // 纬度
  final double longitude; // 经度
  final int geofenceRadius; // 地理围栏半径（米），默认 200
  final int isDefault; // 0/1 是否为默认地点
  final String createdAt;
  final String updatedAt;

  CompanyLocation({
    this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.geofenceRadius = 200,
    this.isDefault = 0,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  /// 从数据库 Map 构造
  factory CompanyLocation.fromMap(Map<String, dynamic> map) {
    return CompanyLocation(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      geofenceRadius: (map['geofence_radius'] as int?) ?? 200,
      isDefault: (map['is_default'] as int?) ?? 0,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'geofence_radius': geofenceRadius,
      'is_default': isDefault,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  CompanyLocation copyWith({
    int? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? geofenceRadius,
    int? isDefault,
    String? createdAt,
    String? updatedAt,
  }) {
    return CompanyLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  @override
  String toString() =>
      'CompanyLocation(id: $id, name: $name, '
      'lat: $latitude, lng: $longitude, radius: ${geofenceRadius}m)';
}
