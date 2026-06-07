import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/company_location.dart';
import '../utils/geofence_validator.dart';
import '../widgets/geofence_radius_widget.dart';

/// 公司地点设置页面
///
/// 功能：
/// - 添加/编辑公司地点（名称、地址、经纬度）
/// - 使用 [GeofenceRadiusPicker] 选择围栏半径
/// - 使用 [GeofenceValidator] 验证半径合法性
/// - 超过 1000 米时弹出 [GeofenceConfirmDialog] 确认
/// - 设置默认打卡地点
/// - 删除公司地点
class LocationSettingsScreen extends StatelessWidget {
  const LocationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.locationTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: L10n.locationAdd,
            onPressed: () =>
                _showLocationEditDialog(context, provider, null),
          ),
        ],
      ),
      body: provider.locations.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(L10n.locationNoData,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(L10n.tr('添加公司地点以启用位置打卡功能',
                      'Add company locations to enable geofence punch'),
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_location),
                    label: Text(L10n.locationAdd),
                    onPressed: () =>
                        _showLocationEditDialog(context, provider, null),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.locations.length,
              itemBuilder: (context, index) {
                final location = provider.locations[index];
                final isDefault =
                    provider.defaultLocation?.id == location.id;
                return _LocationCard(
                  location: location,
                  isDefault: isDefault,
                  onEdit: () => _showLocationEditDialog(
                      context, provider, location),
                  onSetDefault: () =>
                      provider.setDefaultLocation(location.id!),
                  onDelete: () => _confirmDelete(
                      context, provider, location, isDefault),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, SettingsProvider provider,
      CompanyLocation location, bool isDefault) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.delete),
        content: Text(isDefault
            ? L10n.tr(
                '「${location.name}」是默认地点，删除后需要重设默认地点。\n确定要删除吗？',
                '"${location.name}" is the default location. Confirm deletion?')
            : L10n.tr('确定要删除「${location.name}」吗？',
                'Are you sure to delete "${location.name}"?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteLocation(location.id!);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(L10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _showLocationEditDialog(BuildContext context,
      SettingsProvider provider, CompanyLocation? existing) async {
    final isEditing = existing != null;
    final nameCtrl =
        TextEditingController(text: isEditing ? existing.name : '');
    final addressCtrl =
        TextEditingController(text: isEditing ? existing.address ?? '' : '');
    final latCtrl = TextEditingController(
        text: isEditing ? existing.latitude.toString() : '');
    final lngCtrl = TextEditingController(
        text: isEditing ? existing.longitude.toString() : '');
    int radius = isEditing ? existing.geofenceRadius : 200;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(isEditing ? L10n.locationEdit : L10n.locationAdd),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: L10n.locationName,
                        hintText: L10n.tr('例如：公司总部', 'e.g. Company HQ'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: L10n.locationAddress,
                        hintText: L10n.tr('例如：XX 路 A 座', 'e.g. XX Road, Building A'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latCtrl,
                            decoration: InputDecoration(
                              labelText: L10n.locationLatitude,
                              hintText: L10n.tr('例如：39.9042', 'e.g. 39.9042'),
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: lngCtrl,
                            decoration: InputDecoration(
                              labelText: L10n.locationLongitude,
                              hintText: L10n.tr('例如：116.4074', 'e.g. 116.4074'),
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ---- 围栏半径选择器 ----
                    GeofenceRadiusPicker(
                      radius: radius,
                      onChanged: (v) => setState(() => radius = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(L10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    // ===== 数据校验 =====
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(L10n.tr('请输入地点名称', 'Please enter location name'))),
                      );
                      return;
                    }
                    final lat = double.tryParse(latCtrl.text);
                    final lng = double.tryParse(lngCtrl.text);
                    if (lat == null || lng == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(L10n.tr('请输入有效的经纬度', 'Please enter valid coordinates'))),
                      );
                      return;
                    }
                    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(L10n.tr('经纬度数值超出有效范围', 'Coordinates out of range'))),
                      );
                      return;
                    }

                    // ===== GeofenceValidator 校验 =====
                    final validation = GeofenceValidator.validate(radius);
                    if (validation.requiresAdjustment) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(validation.message)),
                      );
                      if (validation.suggestedValue != null) {
                        setState(() => radius = validation.suggestedValue!);
                      }
                      return;
                    }

                    // ===== 超过 1000 米时确认 =====
                    if (validation.requiresConfirmation) {
                      final confirmed = await GeofenceConfirmDialog.show(
                        context: ctx,
                        radius: radius,
                      );
                      if (!confirmed) {
                        return;
                      }
                    }

                    // ===== 保存地点 =====
                    final location = CompanyLocation(
                      id: isEditing ? existing.id : null,
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty
                          ? null
                          : addressCtrl.text.trim(),
                      latitude: lat,
                      longitude: lng,
                      geofenceRadius: radius,
                      isDefault: isEditing ? existing.isDefault : 0,
                    );

                    if (isEditing) {
                      provider.updateLocation(location);
                    } else {
                      provider.addLocation(location);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(L10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 公司地点卡片组件
class _LocationCard extends StatelessWidget {
  final CompanyLocation location;
  final bool isDefault;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _LocationCard({
    required this.location,
    required this.isDefault,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDefault ? Icons.location_on : Icons.location_on_outlined,
                  color: isDefault ? Colors.red : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            location.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (isDefault)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(L10n.locationDefault,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.red)),
                            ),
                        ],
                      ),
                      if (location.address != null &&
                          location.address!.isNotEmpty)
                        Text(location.address!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'default':
                        onSetDefault();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit),
                        title: Text(L10n.edit),
                        dense: true,
                      ),
                    ),
                    if (!isDefault)
                      PopupMenuItem(
                        value: 'default',
                        child: ListTile(
                          leading: const Icon(Icons.star),
                          title: Text(L10n.locationSetDefault),
                          dense: true,
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: Text(L10n.delete,
                            style: const TextStyle(color: Colors.red)),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _infoChip(Icons.pin_drop,
                    '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}'),
                const SizedBox(width: 8),
                _infoChip(
                    Icons.straighten, '${location.geofenceRadius}m'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
