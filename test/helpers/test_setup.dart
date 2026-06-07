/// 测试环境初始化辅助
///
/// 在测试中使用真实 SQLite 数据库（FFI 模式），
/// 避免直接依赖 sqflite 原生平台插件。

import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

/// 在测试的 main() 最开头调用，初始化 sqflite FFI 工厂
///
/// 使用示例：
/// ```dart
/// import '../helpers/test_setup.dart';
///
/// void main() {
///   setupTestDatabase();
///   // ... 测试代码
/// }
/// ```
void setupTestDatabase() {
  databaseFactory = databaseFactoryFfi;
}
