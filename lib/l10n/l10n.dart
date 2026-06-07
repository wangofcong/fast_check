/// 应用国际化支持
///
/// 支持中文和英文，所有 UI 字符串集中管理。
/// 使用方式：L10n.homeTitle 或 L10n.tr('确定', 'OK')
///
/// 语言由 SettingsProvider 管理，设置后可持久化。
class L10n {
  L10n._();

  static String _code = 'zh';
  static String get languageCode => _code;

  /// 设置当前语言代码
  static void setLanguage(String code) {
    _code = code;
  }

  /// 根据当前语言选择字符串
  static String tr(String zh, String en) => _code == 'zh' ? zh : en;

  // ==================================================================
  //  通用
  // ==================================================================
  static String get ok => tr('确定', 'OK');
  static String get cancel => tr('取消', 'Cancel');
  static String get save => tr('保存', 'Save');
  static String get delete => tr('删除', 'Delete');
  static String get edit => tr('编辑', 'Edit');
  static String get add => tr('添加', 'Add');
  static String get close => tr('关闭', 'Close');
  static String get back => tr('返回', 'Back');
  static String get retry => tr('重试', 'Retry');
  static String get refresh => tr('刷新', 'Refresh');
  static String get loading => tr('加载中...', 'Loading...');
  static String get noData => tr('暂无数据', 'No data');
  static String get confirm => tr('确认', 'Confirm');
  static String get search => tr('搜索', 'Search');
  static String get reset => tr('重置', 'Reset');
  static String get settings => tr('设置', 'Settings');
  static String get enabled => tr('已启用', 'Enabled');
  static String get disabled => tr('已禁用', 'Disabled');
  static String get onLabel => tr('开', 'On');
  static String get offLabel => tr('关', 'Off');
  static String get minutes => tr('分钟', 'min');
  static String get seconds => tr('秒', 'sec');
  static String get days => tr('天', 'days');
  static String get hours => tr('小时', 'hours');
  static String get months => tr('月', 'months');
  static String get year => tr('年', 'year');

  // ==================================================================
  //  App 标题
  // ==================================================================
  static String get appTitle => tr('打卡提醒', 'Punch Reminder');
  static String get appShortTitle => tr('打卡提醒', 'Punch Reminder');

  // ==================================================================
  //  底部导航
  // ==================================================================
  static String get navHome => tr('首页', 'Home');
  static String get navRecords => tr('记录', 'Records');
  static String get navAnalysis => tr('分析', 'Analysis');
  static String get navSettings => tr('设置', 'Settings');

  // ==================================================================
  //  Drawer 菜单
  // ==================================================================
  static String get drawerNavigation => tr('导航', 'Navigation');
  static String get drawerHome => tr('首页', 'Home');
  static String get drawerRecords => tr('打卡记录', 'Punch Records');
  static String get drawerAnalysis => tr('打卡分析', 'Punch Analysis');
  static String get drawerTools => tr('工具', 'Tools');
  static String get drawerStatus => tr('监测状态', 'Monitor Status');
  static String get drawerAiReport => tr('AI 智能分析报告', 'AI Analysis Report');
  static String get drawerAiSettings => tr('AI 设置', 'AI Settings');
  static String get drawerDataManagement => tr('数据管理', 'Data Management');
  static String get drawerOther => tr('其他', 'Other');
  static String get drawerAppSettings => tr('应用设置', 'App Settings');

  // ==================================================================
  //  首页 (HomeScreen)
  // ==================================================================
  static String get homeTitle => tr('打卡提醒', 'Punch Reminder');
  static String get homeTooltipMenu => tr('菜单', 'Menu');
  static String get homeTooltipStatus => tr('监测状态', 'Monitor Status');
  static String get homeTooltipSettings => tr('设置', 'Settings');
  static String get homeTodayPunch => tr('今日打卡', "Today's Punch");
  static String get homeCurrentPeriod => tr('当前时段', 'Current Period');
  static String get homeScheduleName => tr('排班名称', 'Schedule Name');
  static String get homePunchIn => tr('上班打卡', 'Punch In');
  static String get homePunchOut => tr('下班打卡', 'Punch Out');
  static String get homeWorkDuration => tr('工作时长', 'Work Duration');
  static String get homeAlreadyPunchedIn =>
      tr('✅ 已打卡', '✅ Punched In');
  static String get homeNotPunchedIn => tr('⏳ 未打卡', '⏳ Not Punched');
  static String get homeAlreadyPunchedOut =>
      tr('✅ 已打卡', '✅ Punched Out');
  static String get homeNotPunchedOut => tr('⏳ 未打卡', '⏳ Not Punched');
  static String get homeWeeklyRecords => tr('最近一周打卡记录', 'Recent Week Records');
  static String get homeNoRecords => tr('本周暂无打卡记录', 'No records this week');
  static String get homeInProgress => tr('进行中', 'In Progress');
  static String get homeNotPunchedShort => tr('未打卡', 'Not Punched');
  static String get homeQuickStatus => tr('监测状态', 'Monitor Status');
  static String get homeQuickSchedule => tr('排班设置', 'Schedule Settings');
  static String get homeQuickLocation => tr('地址设置', 'Location Settings');

  static String homeDayOfWeek(int w) {
    final zh = ['一', '二', '三', '四', '五', '六', '日'];
    final en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _code == 'zh' ? '周${zh[w - 1]}' : en[w - 1];
  }

  static String get homeTodayLabel => tr('今天', 'Today');
  static String homeElapsedMinutes(int minutes) =>
      tr('$minutes分钟', '$minutes min');

  // ==================================================================
  //  打卡记录 (PunchHistoryScreen)
  // ==================================================================
  static String get historyTitle => tr('打卡记录', 'Punch Records');
  static String get historyByMonth => tr('按月份查看', 'By Month');
  static String get historyExport => tr('导出数据', 'Export Data');
  static String get historyNoRecords => tr('暂无打卡记录', 'No punch records');
  static String get historyTotalDays => tr('总天数', 'Total Days');
  static String get historyPunchIn => tr('上班', 'In');
  static String get historyPunchOut => tr('下班', 'Out');
  static String get historyDuration => tr('时长', 'Duration');
  static String get historyStatus => tr('状态', 'Status');
  static String get historyLate => tr('迟到', 'Late');
  static String get historyEarlyLeave => tr('早退', 'Early Leave');
  static String get historyOnTime => tr('正常', 'On Time');
  static String get historyOvertime => tr('加班', 'Overtime');
  static String get historyExportSuccess => tr('导出成功', 'Export successful');
  static String get historyExportFail => tr('导出失败', 'Export failed');
  static String get historyAllRecords => tr('所有记录', 'All Records');

  // ==================================================================
  //  打卡分析 (PunchAnalysisScreen)
  // ==================================================================
  static String get analysisTitle => tr('打卡数据分析', 'Punch Analysis');
  static String get analysisThisMonth => tr('本月', 'This Month');
  static String get analysisLastMonth => tr('上月', 'Last Month');
  static String get analysisLastThreeMonths => tr('近三月', 'Last 3 Months');
  static String get analysisCustom => tr('自定义', 'Custom');
  static String get analysisSelectRange => tr('选择分析时间段', 'Select Date Range');

  static String get analysisAttendance => tr('出勤', 'Attendance');
  static String get analysisPunctuality => tr('准时率', 'Punctuality');
  static String get analysisAvgWorkHour => tr('平均工时', 'Avg Work Time');
  static String get analysisLate => tr('迟到', 'Late');
  static String get analysisOvertime => tr('加班', 'Overtime');
  static String get analysisMissing => tr('缺卡', 'Missing Punch');

  static String get analysisChartDailyWork => tr('每日工时', 'Daily Work');
  static String get analysisChartTrend => tr('打卡趋势', 'Punch Trend');
  static String get analysisChartQuality => tr('出勤质量', 'Attendance Quality');
  static String get analysisChartOvertime => tr('加班分析', 'Overtime Analysis');

  static String get analysisNoData => tr('暂无完整打卡记录', 'No complete records');
  static String get analysisNoDataShort => tr('暂无数据', 'No data');
  static String get analysisNoOvertimePeriod =>
      tr('该时间段无加班记录', 'No overtime this period');
  static String get analysisNoOvertimeMonth =>
      tr('本月无加班记录', 'No overtime this month');

  static String get analysisAiButton => tr('AI 智能分析', 'AI Analysis');
  static String get analysisAiDescription =>
      tr('基于打卡数据生成工作习惯总结与改进建议',
          'Generate work habit summary and suggestions');
  static String get analysisAiCached => tr('已有', 'Cached');
  static String analysisAiCachedTime(String time) =>
      tr('上次报告: $time · 点击查看', 'Last report: $time · View');

  static String get analysisAnomalyTitle => tr('异常检测', 'Anomaly Detection');
  static String get analysisConsecutiveLate => tr('连续迟到', 'Consecutive Late');
  static String get analysisExcessiveOvertime =>
      tr('过度加班', 'Excessive Overtime');
  static String get analysisEarlyLeave => tr('早退', 'Early Leave');
  static String get analysisNoAnomalyPeriod =>
      tr('该时间段无异常打卡行为', 'No anomalies this period');
  static String get analysisNoAnomalyMonth =>
      tr('本月无异常打卡行为', 'No anomalies this month');

  static String get analysisOvertimeTitle => tr('加班分析', 'Overtime Analysis');
  static String get analysisOvertimeDays => tr('加班天数', 'Overtime Days');
  static String get analysisOvertimeTotal => tr('总加班时长', 'Total Overtime');
  static String get analysisOvertimeWeekday =>
      tr('工作日加班', 'Weekday Overtime');
  static String get analysisOvertimeWeekend =>
      tr('周末加班', 'Weekend Overtime');
  static String get analysisOvertimeMaxDay => tr('最长加班日', 'Max Overtime Day');
  static String get analysisLoadingFailed =>
      tr('加载失败', 'Loading failed');

  // ==================================================================
  //  设置 (SettingsScreen)
  // ==================================================================
  static String get settingsTitle => tr('设置', 'Settings');
  static String get settingsLanguage => tr('语言设置', 'Language');
  static String get settingsLanguageZh => tr('中文', 'Chinese');
  static String get settingsLanguageEn => tr('英文', 'English');
  static String get settingsLanguageHint =>
      tr('选择显示语言，默认为系统语言', 'Select display language, defaults to system');
  static String get settingsGeneral => tr('通用设置', 'General Settings');
  static String get settingsReminder =>
      tr('上下班打卡提醒', 'Punch Reminder');
  static String get settingsReminderDesc =>
      tr('到设定时间后自动提醒打卡', 'Auto remind at scheduled times');
  static String get settingsAutoPunch => tr('自动打卡跳转', 'Auto Punch Jump');
  static String get settingsAutoPunchDesc =>
      tr('到打卡时间自动打开第三方 App', 'Auto open third-party app at punch time');
  static String get settingsAutoLocation =>
      tr('上班自动打卡（位置触发）', 'Auto Punch In (Location)');
  static String get settingsAutoLocationDesc =>
      tr('进入公司地理围栏范围自动打卡',
          'Auto punch in when entering geofence area');
  static String get settingsDelayPunch => tr('下班打卡延迟', 'Delay Punch Out');
  static String get settingsDelayPunchDesc =>
      tr('下班时延迟打卡避免忘打', 'Delay punch out to avoid missing');
  static String get settingsAiSummary => tr('AI 智能总结', 'AI Summary');
  static String get settingsAiSummaryDesc =>
      tr('生成月度打卡行为总结报告', 'Generate monthly punch summary report');
  static String get settingsInterval => tr('提醒间隔', 'Reminder Interval');
  static String get settingsIntervalDesc =>
      tr('每次提醒之间的间隔时间', 'Time between reminders');
  static String get settingsVibration => tr('震动时长', 'Vibration Duration');
  static String get settingsVibrationDesc =>
      tr('提醒时设备震动时长', 'Vibration duration when reminding');
  static String get settingsDataRetention =>
      tr('数据保留天数', 'Data Retention Days');
  static String get settingsDataRetentionDesc =>
      tr('打卡记录保留的天数', 'Days to keep punch records');
  static String get settingsSchedule => tr('排班管理', 'Schedule Management');
  static String get settingsLocation => tr('公司地点', 'Company Locations');
  static String get settingsThirdApp => tr('第三方 App', 'Third-party Apps');
  static String get settingsAiConfig => tr('AI 设置', 'AI Settings');
  static String get settingsDataManagement => tr('数据管理', 'Data Management');
  static String get settingsAbout => tr('关于', 'About');
  static String get settingsVersion => tr('版本', 'Version');
  static String get settingsPunchReminderFeatures =>
      tr('打卡提醒功能设置', 'Punch Reminder Feature Settings');
  static String get settingsFeatureSettings =>
      tr('功能设置', 'Feature Settings');

  // ==================================================================
  //  AI 报告 (AiReportScreen)
  // ==================================================================
  static String get aiReportTitle => tr('AI 智能分析报告', 'AI Analysis Report');
  static String get aiReportGenerate => tr('生成报告', 'Generate Report');
  static String get aiReportRegenerate => tr('重新生成', 'Regenerate');
  static String get aiReportGenerating => tr('生成中，请稍候...', 'Generating...');
  static String get aiReportError => tr('生成失败', 'Generation failed');
  static String get aiReportNotConfigured => tr('AI 分析未配置', 'AI Not Configured');
  static String get aiReportGoSettings => tr('去设置', 'Go to Settings');
  static String get aiReportCacheFound => tr('已有', 'Cached');
  static String get aiReportGeneratedAt => tr('生成时间', 'Generated at');

  static String get aiReportConfigHint => tr(
      '请先在「设置 > AI 智能分析设置」中配置 DeepSeek API Key，'
      '以启用 AI 分析功能。\n\n'
      '您的 API Key 仅存储在本地，数据会进行脱敏处理。',
      'Please configure DeepSeek API Key in "Settings > AI Settings" '
      'to enable AI analysis.\n\n'
      'Your API Key is stored locally, data is anonymized.');

  // ==================================================================
  //  AI 设置 (AiSettingsScreen)
  // ==================================================================
  static String get aiSettingsTitle => tr('AI 智能分析设置', 'AI Settings');
  static String get aiSettingsApiKey => tr('API Key', 'API Key');
  static String get aiSettingsApiKeyHint =>
      tr('输入 DeepSeek API Key', 'Enter DeepSeek API Key');
  static String get aiSettingsModel => tr('模型名称', 'Model Name');
  static String get aiSettingsModelHint =>
      tr('如 deepseek-v4-flash', 'e.g. deepseek-v4-flash');
  static String get aiSettingsApiUrl => tr('API 地址', 'API URL');
  static String get aiSettingsApiUrlHint =>
      tr('如 https://api.deepseek.com/v1', 'e.g. https://api.deepseek.com/v1');
  static String get aiSettingsAnonymize => tr('数据脱敏', 'Anonymize Data');
  static String get aiSettingsAnonymizeDesc =>
      tr('发送 AI 分析前脱敏打卡时间等敏感信息',
          'Anonymize sensitive info before AI analysis');
  static String get aiSettingsSaved => tr('配置已保存', 'Settings saved');
  static String get aiSettingsSaveFail => tr('保存失败', 'Save failed');

  // ==================================================================
  //  数据管理 (DataSettingsScreen)
  // ==================================================================
  static String get dataSettingsTitle => tr('数据管理', 'Data Management');
  static String get dataSettingsStats => tr('数据统计', 'Data Statistics');
  static String get dataSettingsRecordCount => tr('打卡记录数', 'Punch Records');
  static String get dataSettingsScheduleCount => tr('排班数', 'Schedules');
  static String get dataSettingsLocationCount => tr('地点数', 'Locations');
  static String get dataSettingsAppCount => tr('第三方 App 数', 'Third-party Apps');
  static String get dataSettingsCleanup => tr('数据清理', 'Data Cleanup');
  static String get dataSettingsCleanupConfirm =>
      tr('确定要清理所有数据吗？此操作不可恢复。',
          'Are you sure to clear all data? This cannot be undone.');
  static String get dataSettingsCleanSuccess =>
      tr('清理成功', 'Cleaned successfully');
  static String get dataSettingsExport => tr('导出数据', 'Export Data');
  static String get dataSettingsExportSuccess =>
      tr('导出成功', 'Export successful');
  static String get dataSettingsExportFail =>
      tr('导出失败', 'Export failed');
  static String get dataSettingsCleanAll => tr('清理所有数据', 'Clear All Data');
  static String get dataSettingsExportAll => tr('导出所有数据', 'Export All Data');

  // ==================================================================
  //  详情 (PunchDetailScreen)
  // ==================================================================
  static String get detailTitle => tr('打卡详情', 'Punch Detail');
  static String get detailPunchInTime => tr('上班时间', 'Punch In Time');
  static String get detailPunchOutTime => tr('下班时间', 'Punch Out Time');
  static String get detailPunchInType => tr('打卡方式', 'Punch In Method');
  static String get detailPunchOutType => tr('打卡方式', 'Punch Out Method');
  static String get detailWorkDuration => tr('工作时长', 'Work Duration');
  static String get detailOvertime => tr('加班时长', 'Overtime');
  static String get detailStatus => tr('状态', 'Status');
  static String get detailNotes => tr('备注', 'Notes');
  static String get detailManual => tr('手动', 'Manual');
  static String get detailAutoJump => tr('自动跳转', 'Auto Jump');
  static String get detailAutoLocation => tr('位置触发', 'Location Trigger');

  // ==================================================================
  //  状态 (StatusScreen)
  // ==================================================================
  static String get statusTitle => tr('监测状态', 'Monitor Status');
  static String get statusEngine => tr('提醒引擎', 'Reminder Engine');
  static String get statusEngineRunning => tr('运行中', 'Running');
  static String get statusEngineStopped => tr('已停止', 'Stopped');
  static String get statusLocation => tr('定位状态', 'Location Status');
  static String get statusInsideFence => tr('在公司范围内', 'Inside Geofence');
  static String get statusOutsideFence =>
      tr('在公司范围外', 'Outside Geofence');
  static String get statusLocationUnknown => tr('未知', 'Unknown');
  static String get statusSchedule => tr('当前排班', 'Current Schedule');
  static String get statusToday => tr('今日', 'Today');
  static String get statusServiceStatus => tr('服务状态', 'Service Status');

  // ==================================================================
  //  排班设置 (ScheduleSettings)
  // ==================================================================
  static String get scheduleTitle => tr('排班设置', 'Schedule Settings');
  static String get scheduleAdd => tr('添加排班', 'Add Schedule');
  static String get scheduleEdit => tr('编辑排班', 'Edit Schedule');
  static String get scheduleName => tr('排班名称', 'Schedule Name');
  static String get schedulePunchInStart => tr('上班开始', 'Punch In Start');
  static String get schedulePunchInEnd => tr('上班截止', 'Punch In End');
  static String get schedulePunchOutStart => tr('下班开始', 'Punch Out Start');
  static String get schedulePunchOutEnd => tr('下班截止', 'Punch Out End');
  static String get scheduleWeekDays => tr('工作日', 'Work Days');
  static String get scheduleMon => tr('一', 'Mon');
  static String get scheduleTue => tr('二', 'Tue');
  static String get scheduleWed => tr('三', 'Wed');
  static String get scheduleThu => tr('四', 'Thu');
  static String get scheduleFri => tr('五', 'Fri');
  static String get scheduleSat => tr('六', 'Sat');
  static String get scheduleSun => tr('日', 'Sun');
  static String get scheduleDeleteConfirm =>
      tr('确定要删除该排班吗？', 'Are you sure to delete this schedule?');

  // ==================================================================
  //  地点设置 (LocationSettings)
  // ==================================================================
  static String get locationTitle => tr('公司地点', 'Company Locations');
  static String get locationAdd => tr('添加地点', 'Add Location');
  static String get locationEdit => tr('编辑地点', 'Edit Location');
  static String get locationName => tr('地点名称', 'Location Name');
  static String get locationAddress => tr('地址', 'Address');
  static String get locationRadius => tr('围栏半径', 'Geofence Radius');
  static String get locationSetDefault => tr('设为默认', 'Set as Default');
  static String get locationDefault => tr('默认', 'Default');

  // ==================================================================
  //  地图选点 (MapPickerScreen)
  // ==================================================================
  static String get mapPickerTitle => tr('选择地点', 'Pick Location');
  static String get mapPickerSearchHint => tr('搜索地点名称或地址...', 'Search place name or address...');
  static String get mapPickerTapHint => tr('点击地图选择位置...', 'Tap on the map to pick a location...');
  static String get mapPickerPickOnMap => tr('在地图上选择位置', 'Pick on Map');
  static String get mapPickerSearchFail => tr('搜索失败', 'Search failed');

  // ==================================================================
  //  第三方 App (ThirdAppSettings)
  // ==================================================================
  static String get thirdAppTitle => tr('第三方 App', 'Third-party Apps');
  static String get thirdAppAdd => tr('添加 App', 'Add App');
  static String get thirdAppEdit => tr('编辑 App', 'Edit App');
  static String get thirdAppName => tr('App 名称', 'App Name');
  static String get thirdAppPackage => tr('包名', 'Package Name');
  static String get thirdAppUrlScheme => tr('URL Scheme', 'URL Scheme');
  static String get thirdAppPunchInTarget =>
      tr('上班打卡目标', 'Punch In Target');
  static String get thirdAppPunchOutTarget =>
      tr('下班打卡目标', 'Punch Out Target');
  static String get thirdAppDeleteConfirm =>
      tr('确定要删除该 App 配置吗？', 'Are you sure to delete this app config?');

  // ==================================================================
  //  新增：状态页面 (StatusScreen)
  // ==================================================================
  static String get statusEngineCard => tr('引擎状态', 'Engine Status');
  static String get statusCheckInterval => tr('检查间隔', 'Check Interval');
  static String statusEveryNMinutes(int n) =>
      tr('每 $n 分钟', 'Every $n min');
  static String get statusNotSet => tr('未设置', 'Not Set');
  static String get statusTodayNotifications =>
      tr('今日通知次数', "Today's Notifications");
  static String statusNTimes(int n) => tr('$n 次', '$n times');
  static String get statusLastCheck => tr('上次检查', 'Last Check');
  static String get statusFeatureStatus => tr('功能启用情况', 'Feature Status');
  static String get statusDistanceDetails => tr('距离详情', 'Distance Details');
  static String get statusCompanyLocation => tr('公司地点', 'Company Location');

  // ==================================================================
  //  新增：详情页面 (PunchDetailScreen)
  // ==================================================================
  static String get detailNotesSaved => tr('备注已保存', 'Notes saved');
  static String detailSaveFailed(String error) =>
      tr('保存失败: $error', 'Save failed: $error');
  static String get detailComplete => tr('已完成打卡', 'Complete');
  static String get detailPartial => tr('部分打卡', 'Partial');
  static String get detailPunchTimes => tr('打卡时间', 'Punch Times');
  static String get detailAttendanceInfo => tr('考勤详情', 'Attendance Info');
  static String get detailMetaInfo => tr('记录信息', 'Record Info');
  static String get detailRecordId => tr('记录 ID', 'Record ID');
  static String get detailScheduleId => tr('排班 ID', 'Schedule ID');
  static String get detailCreatedAt => tr('创建时间', 'Created At');
  static String get detailUpdatedAt => tr('更新时间', 'Updated At');
  static String get detailNotPunched => tr('未打卡', 'Not Punched');
  static String get detailAddNotes => tr('添加备注...', 'Add notes...');
  static String get detailSaveNotes => tr('保存备注', 'Save Notes');
  static String get detailYes => tr('是', 'Yes');
  static String get detailNo => tr('否', 'No');
  static String detailFormattedDuration(int minutes) {
    if (minutes <= 0) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return _code == 'zh' ? '${h}小时${m}分钟' : '${h}h ${m}m';
  }

  // ==================================================================
  //  新增：月度统计卡片 (MonthlyStatsCard)
  // ==================================================================
  static String statsAttendanceDays(int attended, int total) =>
      tr('$attended / $total 天', '$attended / $total days');
  static String statsPercent(double rate) =>
      '${(rate * 100).toStringAsFixed(0)}%';
  static String statsTimes(int n) => tr('$n 次', '$n times');
  static String statsMonthYear(int year, String monthName) =>
      tr('$year年 $monthName', '$monthName $year');
  static String get statsAttendance => tr('出勤', 'Attendance');
  static String get statsPunctuality => tr('准时率', 'Punctuality');
  static String get statsAvgWork => tr('平均工时', 'Avg Work');
  static String get statsOvertime => tr('加班', 'Overtime');
  static String get statsLate => tr('迟到', 'Late');
  static String get statsEarlyLeave => tr('早退', 'Early Leave');

  // ==================================================================
  //  新增：列表项 (RecordListItem)
  // ==================================================================
  static String get listNotPunched => tr('未打卡', 'Not Punched');
  static String get listLate => tr('迟到', 'Late');
  static String get listEarlyLeave => tr('早退', 'Early Leave');
  static String listDateFormat(int month, int day, String weekDay) =>
      tr('${month}月${day}日 周$weekDay', '$weekDay $month/$day');

  // ==================================================================
  //  新增：排班设置 (ScheduleSettings) - 补充
  // ==================================================================
  static String get scheduleWorkDays => tr('工作日', 'Work Days');

  // ==================================================================
  //  新增：数据管理 (DataSettingsScreen) - 补充
  // ==================================================================
  static String get dataSettingsDatabaseInfo =>
      tr('数据库信息', 'Database Info');
  static String get dataSettingsDatabaseSize =>
      tr('数据库大小', 'Database Size');
  static String get dataSettingsRecords =>
      tr('打卡记录数', 'Punch Records');
  static String get dataSettingsTableCount =>
      tr('数据表数', 'Table Count');
  static String get dataSettingsActions => tr('操作', 'Actions');

  // ==================================================================
  //  新增：图表组件 (ChartComponents)
  // ==================================================================
  static String get chartDuration => tr('时长', 'Duration');
  static String get chartMinutes => tr('分钟', 'min');
  static String get chartHours => tr('小时', 'hr');
  static String get chartDate => tr('日期', 'Date');
  static String get chartDay => tr('日', 'Day');
  static String get chartTime => tr('时间', 'Time');
  static String get chartWorkDuration => tr('工作时长', 'Work Duration');
  static String get chartPunchTime => tr('打卡时间', 'Punch Time');
  static String get chartNoData => tr('暂无数据', 'No Data');
  static String get chartAbnormal => tr('异常', 'Abnormal');
  static String get chartNormal => tr('正常', 'Normal');

  // ==================================================================
  //  排班设置补充 (ScheduleSettings)
  // ==================================================================
  static String get scheduleDeleteTitle => tr('删除排班', 'Delete Schedule');
  static String scheduleDeleteMsg(String name) =>
      tr('确定要删除「$name」吗？', 'Are you sure to delete "$name"?');
  static String get scheduleNoData => tr('暂无排班', 'No schedules');
  static String get schedulePunchInRange => tr('上班打卡时间范围', 'Punch In Time Range');
  static String get schedulePunchOutRange => tr('下班打卡时间范围', 'Punch Out Time Range');
  static String get scheduleApplyWeekDays => tr('适用星期', 'Apply Week Days');
  static String get scheduleLinkLocation => tr('关联公司地点（可选）', 'Link Location (optional)');
  static String get scheduleNoLink => tr('不关联', 'No Link');
  static String get scheduleSelectWeekday => tr('请选择至少一个适用星期', 'Select at least one work day');
  static String get scheduleInvalidTime => tr('请输入正确的时间格式 HH:mm', 'Enter valid time HH:mm');
  static String get schedulePunchInLabel => tr('上班 ', 'In ');
  static String get schedulePunchOutLabel => tr('下班 ', 'Out ');
  static String get scheduleWeekly => tr('每周 ', 'Weekly ');

  // ==================================================================
  //  地点设置补充 (LocationSettings)
  // ==================================================================
  static String get locationSetupTitle => tr('公司地址设置', 'Company Address Setup');
  static String get locationAddTooltip => tr('添加公司地点', 'Add Company Location');
  static String get locationLatitude => tr('纬度', 'Latitude');
  static String get locationLongitude => tr('经度', 'Longitude');
  static String get locationNoData => tr('暂无公司地点', 'No company locations');

  // ==================================================================
  //  第三方 App 补充 (ThirdAppSettings)
  // ==================================================================
  static String get thirdAppPresetLabel => tr('预设模板', 'Preset Templates');
  static String get thirdAppNoData => tr('暂无第三方 App', 'No third-party apps');
  static String get thirdAppLaunchTest => tr('测试跳转', 'Test Launch');
  static String get thirdAppPunchInHint => tr('上班打卡页面 URL', 'Punch In URL');
  static String get thirdAppPunchOutHint => tr('下班打卡页面 URL', 'Punch Out URL');
  static String get thirdAppChooseInstalled => tr('从已安装 App 中选择', 'Choose from installed apps');
  static String get thirdAppPickerTitle => tr('选择已安装的 App', 'Select Installed App');
  static String get thirdAppPickerSearchHint => tr('搜索 App 名称或包名...', 'Search app name or package...');
  static String get thirdAppPickerNoMatch => tr('未找到匹配的应用', 'No matching apps found');
  static String get thirdAppPickerNoApps => tr('未找到可用的应用', 'No available apps found');
  static String get thirdAppPickerNotSupported => tr('iOS 不支持列出已安装应用，请手动填写', 'iOS does not support listing installed apps, please enter manually');
  static String get thirdAppPickerFailed => tr('获取应用列表失败', 'Failed to get app list');

  // ==================================================================
  //  数据管理补充 (DataSettingsScreen)
  // ==================================================================
  static String get dataSettingsDatabaseSection => tr('数据库信息', 'Database Info');
  static String get dataSettingsRecordLabel => tr('记录总数', 'Total Records');
  static String get dataSettingsScheduleLabel => tr('排班总数', 'Total Schedules');
  static String get dataSettingsLocationLabel => tr('地点总数', 'Total Locations');
  static String get dataSettingsAppConfigLabel => tr('App 配置数', 'App Configs');
  static String get dataSettingsCleanConfirmTitle => tr('确认清理', 'Confirm Cleanup');
  static String get dataSettingsCleanProgress => tr('清理中...', 'Cleaning...');

  // ==================================================================
  //  图表组件补充 (ChartComponents)
  // ==================================================================
  static String get chartAxisDuration => tr('时长（分钟）', 'Duration (min)');
  static String get chartAxisTime => tr('打卡时间', 'Punch Time');
  static String get chartAxisDate => tr('日期', 'Date');
  static String get chartLabelIn => tr('上班', 'In');
  static String get chartLabelOut => tr('下班', 'Out');
  static String get chartLabelWork => tr('工时', 'Work');
  static String get chartLabelAvg => tr('平均', 'Avg');
  static String get chartTooltipIn => tr('上班打卡', 'Punch In');
  static String get chartTooltipOut => tr('下班打卡', 'Punch Out');
}
