import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/punch_record.dart';
import '../models/work_schedule.dart';
import '../models/company_location.dart';
import '../models/app_settings.dart';
import '../models/third_app_config.dart';
import '../models/delay_record.dart';

/// 数据库服务
///
/// 管理所有本地数据库操作，包含：
/// - 打卡记录 (punch_records)
/// - 上下班排班 (work_schedules)
/// - 公司地点 (company_locations)
/// - 应用设置 (app_settings)
/// - 第三方 App 配置 (third_app_configs)
/// - 延迟打卡记录 (delay_records)
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// 数据库版本号 — 修改 schema 时递增
  static const int _dbVersion = 1;
  static const String _dbName = 'fast_check.db';

  /// 获取数据库实例（单例）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// 数据库配置（开启外键约束）
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// 首次创建数据库 — 建表
  Future<void> _onCreate(Database db, int version) async {
    // ===== 1. 公司地点表 =====
    await db.execute('''
      CREATE TABLE company_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        geofence_radius INTEGER NOT NULL DEFAULT 200,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ===== 2. 上下班排班表 =====
    await db.execute('''
      CREATE TABLE work_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        punch_in_start TEXT NOT NULL,
        punch_in_end TEXT NOT NULL,
        punch_out_start TEXT NOT NULL,
        punch_out_end TEXT NOT NULL,
        company_location_id INTEGER,
        week_days TEXT NOT NULL DEFAULT '[1,2,3,4,5]',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (company_location_id) 
          REFERENCES company_locations(id) 
          ON DELETE SET NULL
      )
    ''');

    // ===== 3. 打卡记录表 =====
    await db.execute('''
      CREATE TABLE punch_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        punch_in_time TEXT,
        punch_out_time TEXT,
        punch_in_type TEXT,
        punch_out_type TEXT,
        is_late INTEGER NOT NULL DEFAULT 0,
        is_early_leave INTEGER NOT NULL DEFAULT 0,
        overtime_minutes INTEGER NOT NULL DEFAULT 0,
        work_duration_minutes INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        schedule_group_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (schedule_group_id) 
          REFERENCES work_schedules(id) 
          ON DELETE SET NULL
      )
    ''');

    // ===== 4. 第三方 App 配置表 =====
    await db.execute('''
      CREATE TABLE third_app_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        package_name TEXT,
        url_scheme TEXT,
        ios_universal_link TEXT,
        is_work_punch_in INTEGER NOT NULL DEFAULT 0,
        is_work_punch_out INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ===== 5. 应用设置表（键值对）=====
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ===== 6. 延迟打卡记录表 =====
    await db.execute('''
      CREATE TABLE delay_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        schedule_group_id INTEGER,
        delay_minutes INTEGER NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (schedule_group_id) 
          REFERENCES work_schedules(id) 
          ON DELETE SET NULL
      )
    ''');

    // ===== 索引 =====
    await db.execute(
        'CREATE INDEX idx_punch_records_date ON punch_records(date)');
    await db.execute(
        'CREATE INDEX idx_punch_records_schedule ON punch_records(schedule_group_id)');
    await db.execute(
        'CREATE INDEX idx_delay_records_date ON delay_records(date)');
    await db.execute(
        'CREATE INDEX idx_work_schedules_enabled ON work_schedules(is_enabled)');

    // ===== 插入默认数据 =====
    await _seedDefaultData(db);
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 后续版本升级逻辑在此添加
    // switch (oldVersion) {
    //   case 1:
    //     await db.execute('ALTER TABLE ...');
    //     continue;
    // }
  }

  /// 插入默认数据
  Future<void> _seedDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. 默认设置
    for (final entry in AppSettingKeys.defaults.entries) {
      await db.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      });
    }

    // 2. 默认排班（工作时间段）
    await db.insert('work_schedules', {
      'name': '工作日',
      'is_enabled': 1,
      'punch_in_start': '09:00',
      'punch_in_end': '11:00',
      'punch_out_start': '17:00',
      'punch_out_end': '19:00',
      'week_days': '[1,2,3,4,5]',
      'sort_order': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  // ====================================================================
  //  打卡记录 (PunchRecord) CRUD
  // ====================================================================

  /// 插入打卡记录
  Future<int> insertPunchRecord(PunchRecord record) async {
    final db = await database;
    return await db.insert('punch_records', record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 根据 ID 查询打卡记录
  Future<PunchRecord?> getPunchRecordById(int id) async {
    final db = await database;
    final maps = await db.query('punch_records', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return PunchRecord.fromMap(maps.first);
  }

  /// 根据日期查询打卡记录
  Future<PunchRecord?> getPunchRecordByDate(String date) async {
    final db = await database;
    final maps =
        await db.query('punch_records', where: 'date = ?', whereArgs: [date]);
    if (maps.isEmpty) return null;
    return PunchRecord.fromMap(maps.first);
  }

  /// 查询日期范围内的打卡记录
  Future<List<PunchRecord>> getPunchRecordsByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final maps = await db.query(
      'punch_records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
    return maps.map((m) => PunchRecord.fromMap(m)).toList();
  }

  /// 查询某月的打卡记录
  Future<List<PunchRecord>> getPunchRecordsByMonth(int year, int month) async {
    final startDate = '$year-${month.toString().padLeft(2, '0')}-01';

    int nextMonth = month + 1;
    int nextYear = year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }
    final endDate =
        '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    return await getPunchRecordsByDateRange(startDate, endDate);
  }

  /// 更新打卡记录
  Future<int> updatePunchRecord(PunchRecord record) async {
    final db = await database;
    return await db.update(
      'punch_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 更新当天的打卡记录（按日期 upsert）
  Future<int> upsertPunchRecordByDate(PunchRecord record) async {
    final db = await database;
    final existing = await getPunchRecordByDate(record.date);
    if (existing != null) {
      return await db.update(
        'punch_records',
        record.copyWith(id: existing.id).toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    } else {
      return await db.insert('punch_records', record.toMap());
    }
  }

  /// 删除打卡记录
  Future<int> deletePunchRecord(int id) async {
    final db = await database;
    return await db.delete('punch_records', where: 'id = ?', whereArgs: [id]);
  }

  /// 清理过期打卡记录
  Future<int> cleanOldPunchRecords(int retentionDays) async {
    final db = await database;
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .toIso8601String()
        .substring(0, 10);
    return await db.delete('punch_records',
        where: 'date < ?', whereArgs: [cutoffDate]);
  }

  /// 获取打卡记录总数
  Future<int> getPunchRecordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM punch_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ====================================================================
  //  上下班排班 (WorkSchedule) CRUD
  // ====================================================================

  /// 插入排班
  Future<int> insertWorkSchedule(WorkSchedule schedule) async {
    final db = await database;
    return await db.insert('work_schedules', schedule.toMap());
  }

  /// 获取所有排班
  Future<List<WorkSchedule>> getAllWorkSchedules() async {
    final db = await database;
    final maps = await db.query('work_schedules', orderBy: 'sort_order ASC');
    return maps.map((m) => WorkSchedule.fromMap(m)).toList();
  }

  /// 获取所有已启用的排班
  Future<List<WorkSchedule>> getEnabledWorkSchedules() async {
    final db = await database;
    final maps = await db.query('work_schedules',
        where: 'is_enabled = 1', orderBy: 'sort_order ASC');
    return maps.map((m) => WorkSchedule.fromMap(m)).toList();
  }

  /// 根据 ID 获取排班
  Future<WorkSchedule?> getWorkScheduleById(int id) async {
    final db = await database;
    final maps =
        await db.query('work_schedules', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return WorkSchedule.fromMap(maps.first);
  }

  /// 更新排班
  Future<int> updateWorkSchedule(WorkSchedule schedule) async {
    final db = await database;
    return await db.update(
      'work_schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  /// 删除排班
  Future<int> deleteWorkSchedule(int id) async {
    final db = await database;
    return await db.delete('work_schedules',
        where: 'id = ?', whereArgs: [id]);
  }

  // ====================================================================
  //  公司地点 (CompanyLocation) CRUD
  // ====================================================================

  /// 插入公司地点
  Future<int> insertCompanyLocation(CompanyLocation location) async {
    final db = await database;
    return await db.insert('company_locations', location.toMap());
  }

  /// 获取所有公司地点
  Future<List<CompanyLocation>> getAllCompanyLocations() async {
    final db = await database;
    final maps = await db.query('company_locations');
    return maps.map((m) => CompanyLocation.fromMap(m)).toList();
  }

  /// 获取默认公司地点
  Future<CompanyLocation?> getDefaultCompanyLocation() async {
    final db = await database;
    final maps = await db.query('company_locations',
        where: 'is_default = 1', limit: 1);
    if (maps.isEmpty) return null;
    return CompanyLocation.fromMap(maps.first);
  }

  /// 根据 ID 获取公司地点
  Future<CompanyLocation?> getCompanyLocationById(int id) async {
    final db = await database;
    final maps = await db.query('company_locations',
        where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return CompanyLocation.fromMap(maps.first);
  }

  /// 更新公司地点
  Future<int> updateCompanyLocation(CompanyLocation location) async {
    final db = await database;
    return await db.update(
      'company_locations',
      location.toMap(),
      where: 'id = ?',
      whereArgs: [location.id],
    );
  }

  /// 设置默认公司地点（清除其他默认标记）
  Future<void> setDefaultCompanyLocation(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'company_locations',
        {'is_default': 0},
      );
      await txn.update(
        'company_locations',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// 删除公司地点
  Future<int> deleteCompanyLocation(int id) async {
    final db = await database;
    return await db.delete('company_locations',
        where: 'id = ?', whereArgs: [id]);
  }

  // ====================================================================
  //  应用设置 (AppSetting) CRUD
  // ====================================================================

  /// 获取设置值
  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps =
        await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  /// 获取设置值（带默认值）
  Future<String> getSettingWithDefault(String key) async {
    final value = await getSetting(key);
    return value ?? AppSettingKeys.defaults[key] ?? '';
  }

  /// 获取布尔类型设置
  Future<bool> getBoolSetting(String key) async {
    final value = await getSetting(key);
    return value == 'true';
  }

  /// 获取整数类型设置
  Future<int> getIntSetting(String key) async {
    final value = await getSetting(key);
    if (value == null) return 0;
    return int.tryParse(value) ?? 0;
  }

  /// 设置值
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      AppSetting(key: key, value: value).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 设置布尔值
  Future<void> setBoolSetting(String key, bool value) async {
    await setSetting(key, value ? 'true' : 'false');
  }

  /// 设置整数值
  Future<void> setIntSetting(String key, int value) async {
    await setSetting(key, value.toString());
  }

  /// 获取所有设置
  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final maps = await db.query('app_settings');
    final map = <String, String>{};
    for (final m in maps) {
      map[m['key'] as String] = m['value'] as String;
    }
    return map;
  }

  /// 重置设置为默认值
  Future<void> resetSettingToDefault(String key) async {
    if (AppSettingKeys.defaults.containsKey(key)) {
      await setSetting(key, AppSettingKeys.defaults[key]!);
    }
  }

  /// 重置所有设置为默认值
  Future<void> resetAllSettings() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('app_settings');
      final now = DateTime.now().toIso8601String();
      for (final entry in AppSettingKeys.defaults.entries) {
        await txn.insert('app_settings', {
          'key': entry.key,
          'value': entry.value,
          'updated_at': now,
        });
      }
    });
  }

  // ====================================================================
  //  第三方 App 配置 (ThirdAppConfig) CRUD
  // ====================================================================

  /// 插入第三方 App 配置
  Future<int> insertThirdAppConfig(ThirdAppConfig config) async {
    final db = await database;
    return await db.insert('third_app_configs', config.toMap());
  }

  /// 获取所有第三方 App 配置
  Future<List<ThirdAppConfig>> getAllThirdAppConfigs() async {
    final db = await database;
    final maps = await db.query('third_app_configs');
    return maps.map((m) => ThirdAppConfig.fromMap(m)).toList();
  }

  /// 获取上班打卡目标 App
  Future<ThirdAppConfig?> getPunchInTargetApp() async {
    final db = await database;
    final maps = await db.query('third_app_configs',
        where: 'is_work_punch_in = 1', limit: 1);
    if (maps.isEmpty) return null;
    return ThirdAppConfig.fromMap(maps.first);
  }

  /// 获取下班打卡目标 App
  Future<ThirdAppConfig?> getPunchOutTargetApp() async {
    final db = await database;
    final maps = await db.query('third_app_configs',
        where: 'is_work_punch_out = 1', limit: 1);
    if (maps.isEmpty) return null;
    return ThirdAppConfig.fromMap(maps.first);
  }

  /// 更新第三方 App 配置
  Future<int> updateThirdAppConfig(ThirdAppConfig config) async {
    final db = await database;
    return await db.update(
      'third_app_configs',
      config.toMap(),
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  /// 设置上班打卡目标 App（清除其他目标标记）
  Future<void> setPunchInTarget(int appId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'third_app_configs',
        {'is_work_punch_in': 0},
      );
      await txn.update(
        'third_app_configs',
        {'is_work_punch_in': 1},
        where: 'id = ?',
        whereArgs: [appId],
      );
    });
  }

  /// 设置下班打卡目标 App（清除其他目标标记）
  Future<void> setPunchOutTarget(int appId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'third_app_configs',
        {'is_work_punch_out': 0},
      );
      await txn.update(
        'third_app_configs',
        {'is_work_punch_out': 1},
        where: 'id = ?',
        whereArgs: [appId],
      );
    });
  }

  /// 删除第三方 App 配置
  Future<int> deleteThirdAppConfig(int id) async {
    final db = await database;
    return await db.delete('third_app_configs',
        where: 'id = ?', whereArgs: [id]);
  }

  // ====================================================================
  //  延迟打卡记录 (DelayRecord) CRUD
  // ====================================================================

  /// 插入延迟记录
  Future<int> insertDelayRecord(DelayRecord record) async {
    final db = await database;
    return await db.insert('delay_records', record.toMap());
  }

  /// 查询某天的延迟记录
  Future<List<DelayRecord>> getDelayRecordsByDate(String date) async {
    final db = await database;
    final maps = await db.query('delay_records',
        where: 'date = ?', whereArgs: [date], orderBy: 'created_at ASC');
    return maps.map((m) => DelayRecord.fromMap(m)).toList();
  }

  /// 查询日期范围内的延迟记录
  Future<List<DelayRecord>> getDelayRecordsByDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final maps = await db.query('delay_records',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date ASC');
    return maps.map((m) => DelayRecord.fromMap(m)).toList();
  }

  // ====================================================================
  //  工具方法
  // ====================================================================

  /// 获取数据库统计信息
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    final recordCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM punch_records'));
    final delayCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM delay_records'));
    final scheduleCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM work_schedules'));
    final locationCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM company_locations'));
    final appCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM third_app_configs'));

    return {
      'punch_records': recordCount ?? 0,
      'delay_records': delayCount ?? 0,
      'work_schedules': scheduleCount ?? 0,
      'company_locations': locationCount ?? 0,
      'third_app_configs': appCount ?? 0,
    };
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
