/// 打卡数据分析页面
///
/// 展示：
/// - 月度统计卡片
/// - 柱状图（每日工作时长）
/// - 折线图（上下班时间趋势）
/// - 饼图（出勤质量分布 + 加班类型分布）
/// - 加班分析
/// - 异常检测预警
/// - 月份切换导航

import 'package:flutter/material.dart';
import '../models/punch_analysis.dart';
import '../services/punch_analysis_service.dart';
import '../services/chart_data_service.dart';
import '../services/ai_summary_service.dart';
import '../services/database_service.dart';
import '../widgets/chart_components.dart';
import '../l10n/l10n.dart';
import 'ai_report_screen.dart';
import 'ai_settings_screen.dart';

/// 显示图表类型
enum ChartTab {
  dailyWork, // 每日工作时长柱状图
  punchTrend, // 打卡时间趋势
  quality, // 出勤质量饼图
  overtime, // 加班分析
}

/// 分析时间段
enum AnalysisPeriod {
  thisMonth,
  lastMonth,
  lastThreeMonths,
  custom,
}

class PunchAnalysisScreen extends StatefulWidget {
  const PunchAnalysisScreen({super.key});

  @override
  State<PunchAnalysisScreen> createState() => _PunchAnalysisScreenState();
}

class _PunchAnalysisScreenState extends State<PunchAnalysisScreen> {
  final PunchAnalysisService _analysisService = PunchAnalysisService();
  final ChartDataService _chartService = ChartDataService();
  final AiSummaryService _aiService = AiSummaryService();
  final DatabaseService _db = DatabaseService();

  /// 自定义日期范围持久化存储的键名
  static const String _keyCustomStart = 'custom_analysis_start_date';
  static const String _keyCustomEnd = 'custom_analysis_end_date';

  late int _currentYear;
  late int _currentMonth;
  AnalysisPeriod _period = AnalysisPeriod.thisMonth;
  /// 保存切换前的 period，取消自定义选择时可恢复
  AnalysisPeriod _previousPeriod = AnalysisPeriod.thisMonth;
  ChartTab _selectedTab = ChartTab.dailyWork;

  /// 日期范围模式状态
  late String _startDate;
  late String _endDate;
  bool _isPeriodMode = false;

  MonthlySummary? _summary;
  PeriodSummary? _periodSummary;
  OvertimeAnalysis? _overtime;
  AnomalyDetection? _anomalies;
  bool _isLoading = false;
  String? _error;

  /// AI 缓存状态
  bool _hasCachedAiReport = false;
  String? _cachedAiReportTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
    _initDateRange(now);
    _loadCustomDateRange();
    _loadData();
    _checkAiCache();
  }

  /// 从本地加载上次保存的自定义日期范围
  Future<void> _loadCustomDateRange() async {
    try {
      final savedStart = await _db.getSetting(_keyCustomStart);
      final savedEnd = await _db.getSetting(_keyCustomEnd);
      if (savedStart != null && savedEnd != null) {
        // 校验保存的日期是否有效（不超过今天）
        final end = DateTime.tryParse(savedEnd);
        final now = DateTime.now();
        if (end != null && !end.isAfter(now)) {
          _startDate = savedStart;
          _endDate = savedEnd;
          // 如果当前是自定义模式，触发重建以刷新日期显示
          if (_period == AnalysisPeriod.custom && mounted) {
            setState(() {});
          }
        }
      }
    } catch (_) {
      // 忽略加载失败，使用默认范围
    }
  }

  /// 保存自定义日期范围到本地
  Future<void> _saveCustomDateRange() async {
    try {
      await _db.setSetting(_keyCustomStart, _startDate);
      await _db.setSetting(_keyCustomEnd, _endDate);
    } catch (_) {
      // 忽略保存失败
    }
  }

  void _initDateRange(DateTime now) {
    final firstDay = DateTime(now.year, now.month, 1);
    _startDate = _fmtDate(firstDay);
    _endDate = _fmtDate(now); // 不能超过今天（日期选择器的 lastDate）
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _checkAiCache() async {
    final isPeriod = _period == AnalysisPeriod.custom || _period == AnalysisPeriod.lastThreeMonths;
    final periodLabel = isPeriod ? '$_startDate ~ $_endDate' : '$_currentYear年$_currentMonth月';
    final reportType = isPeriod ? 'period' : 'monthly';
    final cached = await _aiService.loadCachedReport(reportType, periodLabel);
    if (mounted) {
      setState(() {
        _hasCachedAiReport = cached != null;
        _cachedAiReportTime = cached?.generatedAt.substring(0, 16).replaceAll('T', ' ');
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isPeriodMode = _period == AnalysisPeriod.custom ||
          _period == AnalysisPeriod.lastThreeMonths;
    });

    try {
      if (_isPeriodMode) {
        final summary = await _analysisService.getPeriodSummary(
            _startDate, _endDate);
        final overtime = await _analysisService.analyzeOvertimeByRange(
            _startDate, _endDate);
        final anomalies = await _analysisService.detectAnomaliesByRange(
            _startDate, _endDate);

        if (mounted) {
          setState(() {
            _periodSummary = summary;
            _summary = null;
            _overtime = overtime;
            _anomalies = anomalies;
            _isLoading = false;
          });
        }
      } else {
        final summary = await _analysisService.getMonthlySummary(
            _currentYear, _currentMonth);
        final overtime = await _analysisService.analyzeOvertime(
            _currentYear, _currentMonth);
        final anomalies = await _analysisService.detectAnomalies(
            _currentYear, _currentMonth);

        if (mounted) {
          setState(() {
            _summary = summary;
            _periodSummary = null;
            _overtime = overtime;
            _anomalies = anomalies;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _switchToPeriod(AnalysisPeriod period) {
    final now = DateTime.now();

    // 如果点击的是已选中的自定义，直接弹出日期选择器（不重置状态）
    if (period == AnalysisPeriod.custom && _period == AnalysisPeriod.custom) {
      _pickDateRange();
      return;
    }

    // 保存上一个 period，以便取消自定义时恢复
    _previousPeriod = _period;

    setState(() {
      _period = period;
      // 立即同步更新 _isPeriodMode，确保 UI 路径一致
      _isPeriodMode = period == AnalysisPeriod.custom ||
          period == AnalysisPeriod.lastThreeMonths;
    });

    switch (period) {
      case AnalysisPeriod.thisMonth:
        _currentYear = now.year;
        _currentMonth = now.month;
        _loadData();
        _checkAiCache();
        break;
      case AnalysisPeriod.lastMonth:
        if (now.month == 1) {
          _currentYear = now.year - 1;
          _currentMonth = 12;
        } else {
          _currentYear = now.year;
          _currentMonth = now.month - 1;
        }
        _loadData();
        _checkAiCache();
        break;
      case AnalysisPeriod.lastThreeMonths:
        // 设置为最近三个月
        final threeMonthsAgo = DateTime(now.year, now.month - 2, 1);
        _startDate = _fmtDate(threeMonthsAgo);
        _endDate = _fmtDate(now);
        _loadData();
        _checkAiCache();
        break;
      case AnalysisPeriod.custom:
        // 直接弹出日期选择器
        _pickDateRange();
        break;
    }
  }

  void _prevMonth() {
    if (_isPeriodMode) {
      // 周期模式：将整个日期范围向前移动
      final start = DateTime.tryParse(_startDate);
      final end = DateTime.tryParse(_endDate);
      if (start == null || end == null) return;
      final span = end.difference(start).inDays + 1;
      final newEnd = start.subtract(const Duration(days: 1));
      final newStart = newEnd.subtract(Duration(days: span - 1));
      _startDate = _fmtDate(newStart);
      _endDate = _fmtDate(newEnd);
      // 自定义模式下滑动后保存
      if (_period == AnalysisPeriod.custom) {
        _saveCustomDateRange();
      }
    } else {
      setState(() {
        if (_currentMonth == 1) {
          _currentMonth = 12;
          _currentYear--;
        } else {
          _currentMonth--;
        }
      });
    }
    _loadData();
    _checkAiCache();
  }

  void _nextMonth() {
    final now = DateTime.now();

    if (_isPeriodMode) {
      // 周期模式：将整个日期范围向后移动
      final start = DateTime.tryParse(_startDate);
      final end = DateTime.tryParse(_endDate);
      if (start == null || end == null) return;
      // 不能超过今天
      if (end.isAfter(now) || end.isAtSameMomentAs(now)) return;
      final span = end.difference(start).inDays + 1;
      final newStart = end.add(const Duration(days: 1));
      final newEnd = newStart.add(Duration(days: span - 1));
      // 不能超过今天
      if (newStart.isAfter(now)) return;
      _startDate = _fmtDate(newStart);
      _endDate = _fmtDate(newEnd.isAfter(now) ? now : newEnd);
      // 自定义模式下滑动后保存
      if (_period == AnalysisPeriod.custom) {
        _saveCustomDateRange();
      }
    } else {
      if (_currentYear >= now.year && _currentMonth >= now.month) return;
      setState(() {
        if (_currentMonth == 12) {
          _currentMonth = 1;
          _currentYear++;
        } else {
          _currentMonth++;
        }
      });
    }
    _loadData();
    _checkAiCache();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.analysisTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_summary == null && _periodSummary == null) {
      return Center(child: Text(L10n.analysisNoDataShort));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          // ---- 时间段选择 ----
          _buildPeriodSelector(),
          const SizedBox(height: 8),

          // ---- 月份切换 + 月度统计卡片 ----
          _buildMonthHeader(),
          const SizedBox(height: 8),
          _buildSummaryCards(),
          const SizedBox(height: 8),

          // ---- 图表选项卡 ----
          _buildTabSelector(),
          const SizedBox(height: 8),
          _buildChartContent(),
          const SizedBox(height: 12),

          // ---- 加班分析 ----
          if (_overtime != null && _overtime!.overtimeDaysCount > 0) ...[
            _buildOvertimeSection(),
            const SizedBox(height: 12),
          ],

          // ---- 异常检测 ----
          if (_anomalies != null && _anomalies!.hasAnomalies) ...[
            _buildAnomalySection(),
            const SizedBox(height: 12),
          ],

          // ---- AI 分析按钮 ----
          _buildAiAnalysisButton(),
          const SizedBox(height: 12),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ==================================================================
  //  时间段快捷选择 + 日期范围选择
  // ==================================================================

  Widget _buildPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: SegmentedButton<AnalysisPeriod>(
                    segments: const [
                      ButtonSegment(
                        value: AnalysisPeriod.thisMonth,
                        label: Text('本月', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: AnalysisPeriod.lastMonth,
                        label: Text('上月', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: AnalysisPeriod.lastThreeMonths,
                        label: Text('近三月',
                            style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: AnalysisPeriod.custom,
                        label: Text('自定义',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {_period},
                    onSelectionChanged: (selected) =>
                        _switchToPeriod(selected.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
            if (_period == AnalysisPeriod.custom) ...[
              const SizedBox(height: 8),
              _buildDateRangeRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeRow() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$_startDate  ~  $_endDate',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down,
                      size: 18, color: Colors.grey[500]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: DateTime.tryParse(_startDate) ??
            DateTime(now.year, now.month, 1),
        end: DateTime.tryParse(_endDate) ?? now,
      ),
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: now,
      helpText: '选择分析时间段',
      confirmText: '确定',
      cancelText: '取消',
      saveText: '确定',
      fieldStartHintText: '开始日期',
      fieldEndHintText: '结束日期',
    );

    if (picked != null) {
      setState(() {
        _startDate = _fmtDate(picked.start);
        _endDate = _fmtDate(picked.end);
      });
      _saveCustomDateRange(); // 持久化保存用户的自定义选择
      _loadData();
      _checkAiCache();
    } else {
      // 用户取消了选择器，恢复到切换前的 period
      setState(() {
        _period = _previousPeriod;
        _isPeriodMode = _previousPeriod == AnalysisPeriod.custom ||
            _previousPeriod == AnalysisPeriod.lastThreeMonths;
      });
      // 如果不恢复数据（比如从近三月 -> 自定义 -> 取消），刷新一下
      _loadData();
      _checkAiCache();
    }
  }

  // ==================================================================
  //  月份/周期切换标题
  // ==================================================================

  Widget _buildMonthHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevMonth,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _isPeriodMode
                      ? '$_startDate ~ $_endDate'
                      : '${_currentYear}年 ${_monthName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
            ),
          ],
        ),
      ),
    );
  }

  String get _monthName {
    const names = [
      '1月', '2月', '3月', '4月', '5月', '6月',
      '7月', '8月', '9月', '10月', '11月', '12月'
    ];
    return _summary?.monthName ?? names[_currentMonth - 1];
  }

  // ==================================================================
  //  统计卡片
  // ==================================================================

  Widget _buildSummaryCards() {
    if (_isPeriodMode && _periodSummary != null) {
      return _buildPeriodSummaryCards(_periodSummary!);
    }
    if (_summary != null) {
      return _buildMonthlySummaryCards(_summary!);
    }
    // 防御：如果两者都为空，显示空状态
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('暂无统计数据')),
      ),
    );
  }

  Widget _buildMonthlySummaryCards(MonthlySummary s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.year}年${s.monthName} 概览',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _miniStat(
                        '出勤', '${s.attendedDays}/${s.totalWorkDays}天',
                        Colors.blue, Icons.calendar_today)),
                Expanded(
                    child: _miniStat(
                        '准时率',
                        '${(s.punctualityRate * 100).toStringAsFixed(0)}%',
                        s.punctualityRate >= 0.8
                            ? Colors.green
                            : Colors.orange,
                        Icons.check_circle)),
                Expanded(
                    child: _miniStat('平均工时', s.formattedAvgWorkDuration,
                        Colors.indigo, Icons.timer)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _miniStat('迟到', '${s.lateDays}次',
                        s.lateDays > 0 ? Colors.red : Colors.green,
                        Icons.warning_amber)),
                Expanded(
                    child: _miniStat('加班', s.formattedOvertime,
                        s.totalOvertimeMinutes > 0
                            ? Colors.deepOrange
                            : Colors.grey,
                        Icons.access_time_filled)),
                Expanded(
                    child: _miniStat('缺卡', '${s.missingDays}天',
                        s.missingDays > 0 ? Colors.red : Colors.green,
                        Icons.block)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSummaryCards(PeriodSummary s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.startDate} ~ ${s.endDate} 概览',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _miniStat(
                        '出勤', '${s.attendedDays}/${s.totalDays}天',
                        Colors.blue, Icons.calendar_today)),
                Expanded(
                    child: _miniStat(
                        '准时率',
                        '${(s.punctualityRate * 100).toStringAsFixed(0)}%',
                        s.punctualityRate >= 0.8
                            ? Colors.green
                            : Colors.orange,
                        Icons.check_circle)),
                Expanded(
                    child: _miniStat('平均工时', s.formattedAvgWorkDuration,
                        Colors.indigo, Icons.timer)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _miniStat('迟到', '${s.lateDays}次',
                        s.lateDays > 0 ? Colors.red : Colors.green,
                        Icons.warning_amber)),
                Expanded(
                    child: _miniStat('加班', s.formattedOvertime,
                        s.totalOvertimeMinutes > 0
                            ? Colors.deepOrange
                            : Colors.grey,
                        Icons.access_time_filled)),
                Expanded(
                    child: _miniStat('缺卡', '${s.missingDays}天',
                        s.missingDays > 0 ? Colors.red : Colors.green,
                        Icons.block)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // ==================================================================
  //  图表选项卡
  // ==================================================================

  Widget _buildTabSelector() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _tabChip(L10n.analysisChartDailyWork, ChartTab.dailyWork),
          const SizedBox(width: 8),
          _tabChip(L10n.analysisChartTrend, ChartTab.punchTrend),
          const SizedBox(width: 8),
          _tabChip(L10n.analysisChartQuality, ChartTab.quality),
          const SizedBox(width: 8),
          _tabChip(L10n.analysisChartOvertime, ChartTab.overtime),
        ],
      ),
    );
  }

  Widget _tabChip(String label, ChartTab tab) {
    final isSelected = _selectedTab == tab;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedTab = tab),
      visualDensity: VisualDensity.compact,
    );
  }

  // ==================================================================
  //  图表内容
  // ==================================================================

  Widget _buildChartContent() {
    if (_isPeriodMode && _periodSummary != null) {
      return _buildPeriodChartContent(_periodSummary!);
    }
    if (_summary != null) {
      return _buildMonthlyChartContent(_summary!);
    }
    return _emptyChartCard();
  }

  Widget _buildMonthlyChartContent(MonthlySummary s) {
    switch (_selectedTab) {
      case ChartTab.dailyWork:
        return _buildDailyWorkChart();
      case ChartTab.punchTrend:
        return _buildPunchTrendChart();
      case ChartTab.quality:
        return _buildQualityPie();
      case ChartTab.overtime:
        return _buildOvertimePie();
    }
  }

  Widget _buildPeriodChartContent(PeriodSummary s) {
    switch (_selectedTab) {
      case ChartTab.dailyWork:
        return _buildPeriodDailyWorkChart(s);
      case ChartTab.punchTrend:
        return _buildPeriodPunchTrendChart(s);
      case ChartTab.quality:
        return _buildQualityPie();
      case ChartTab.overtime:
        return _buildOvertimePie();
    }
  }

  Widget _buildDailyWorkChart() {
    if (_summary == null) return _emptyChartCard();
    final chart = _chartService.dailyWorkDurationChart(_summary!);
    if (chart.values.isEmpty) {
      return _emptyChartCard();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chart.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            BarChartWidget(data: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDailyWorkChart(PeriodSummary s) {
    final chart = _chartService.dailyWorkDurationChartForPeriod(s);
    if (chart.values.isEmpty) {
      return _emptyChartCard();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chart.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            BarChartWidget(data: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchTrendChart() {
    if (_summary == null) return _emptyChartCard();
    final inChart = _chartService.punchInTrendChart(_summary!);
    final outChart = _chartService.punchOutTrendChart(_summary!);
    return _buildTrendCards(inChart, outChart);
  }

  Widget _buildPeriodPunchTrendChart(PeriodSummary s) {
    final inChart = _chartService.punchInTrendChartForPeriod(s);
    final outChart = _chartService.punchOutTrendChartForPeriod(s);
    return _buildTrendCards(inChart, outChart);
  }

  Widget _buildTrendCards(LineChartData inChart, LineChartData outChart) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inChart.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: LineChartWidget(
                    data: inChart,
                    lineColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(outChart.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: LineChartWidget(
                    data: outChart,
                    lineColor: Colors.indigo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyChartCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text(L10n.analysisNoData)),
      ),
    );
  }

  Widget _buildQualityPie() {
    if (_isPeriodMode && _periodSummary != null) {
      final chart = _chartService.attendanceQualityPieForPeriod(_periodSummary!);
      return _buildPieCard(chart.title, chart);
    }
    if (_summary != null) {
      final chart = _chartService.attendanceQualityPie(_summary!);
      return _buildPieCard(chart.title, chart);
    }
    return _emptyChartCard();
  }

  Widget _buildPieCard(String title, PieChartData chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 12),
            PieChartWidget(data: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildOvertimePie() {
    if (_overtime == null || _overtime!.totalOvertimeMinutes <= 0) {
      return _emptyOvertimeCard();
    }
    final chart = _chartService.overtimeTypePie(_overtime!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(chart.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 12),
            PieChartWidget(data: chart),
          ],
        ),
      ),
    );
  }

  Widget _emptyOvertimeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            _isPeriodMode ? L10n.analysisNoOvertimePeriod : L10n.analysisNoOvertimeMonth,
          ),
        ),
      ),
    );
  }

  // ==================================================================
  //  加班分析区域
  // ==================================================================

  Widget _buildOvertimeSection() {
    final o = _overtime!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time_filled,
                    size: 18, color: Colors.deepOrange),
                const SizedBox(width: 6),
                Text(L10n.analysisOvertimeTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(),
            _detailRow(L10n.analysisOvertimeDays, '${o.overtimeDaysCount} ${L10n.tr('天', 'days')}'),
            const SizedBox(height: 4),
            _detailRow(L10n.analysisOvertimeTotal, o.formattedTotal),
            const SizedBox(height: 4),
            _detailRow(L10n.analysisOvertimeWeekday,
                '${o.weekdayOvertimeMinutes ~/ 60}h${o.weekdayOvertimeMinutes % 60}m'),
            const SizedBox(height: 4),
            _detailRow(L10n.analysisOvertimeWeekend,
                '${o.weekendOvertimeMinutes ~/ 60}h${o.weekendOvertimeMinutes % 60}m'),
            if (o.maxOvertimeDate != null) ...[
              const SizedBox(height: 4),
              _detailRow(L10n.analysisOvertimeMaxDay,
                  '${o.maxOvertimeDate} (${o.maxOvertimeMinutes ~/ 60}h${o.maxOvertimeMinutes % 60}m)'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }

  // ==================================================================
  //  异常检测区域
  // ==================================================================

  Widget _buildAnomalySection() {
    final a = _anomalies!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, size: 18, color: Colors.red),
                const SizedBox(width: 6),
                Text(L10n.analysisAnomalyTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(),
            if (a.consecutiveLateDates.length >= 3)
              _anomalyItem(Icons.schedule, L10n.analysisConsecutiveLate,
                  '${a.consecutiveLateDates.length} ${L10n.tr('天', 'days')}'),
            if (a.excessiveOvertimeDates.isNotEmpty)
              _anomalyItem(
                  Icons.timer_off, L10n.analysisExcessiveOvertime, '${a.excessiveOvertimeDates.length} ${L10n.tr('天', 'days')}'),
            if (a.missingPunchDates.isNotEmpty)
              _anomalyItem(
                  Icons.block, L10n.analysisMissing, '${a.missingPunchDates.length} ${L10n.tr('天', 'days')}'),
            if (a.earlyLeaveDates.isNotEmpty)
              _anomalyItem(Icons.exit_to_app, L10n.analysisEarlyLeave,
                  '${a.earlyLeaveDates.length} ${L10n.tr('次', 'times')}'),
            if (!a.hasAnomalies)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      _isPeriodMode ? L10n.analysisNoAnomalyPeriod : L10n.analysisNoAnomalyMonth,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _anomalyItem(IconData icon, String label, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.red[400]),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[800])),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(detail,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  //  AI 分析按钮
  // ==================================================================

  Widget _buildAiAnalysisButton() {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAiReport(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 智能分析',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasCachedAiReport
                          ? L10n.analysisAiCachedTime(_cachedAiReportTime ?? '')
                          : L10n.analysisAiDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: _hasCachedAiReport
                            ? Colors.teal[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasCachedAiReport)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    L10n.analysisAiCached,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAiReport() async {
    final aiService = AiSummaryService();
    final isConfigured = await aiService.isConfigured();

    if (!isConfigured) {
      if (!mounted) return;
      // 提示用户先配置 API Key
      final shouldGoToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI 分析未配置'),
          content: const Text(
            '请先在「设置 > AI 智能分析设置」中配置 DeepSeek API Key，'
            '以启用 AI 分析功能。\n\n'
            '您的 API Key 仅存储在本地，数据会进行脱敏处理。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );

      if (shouldGoToSettings == true && mounted) {
        // 跳转到设置页面的 AI 设置
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const _SettingsWrapper(),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    if (_isPeriodMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiReportScreen(
            startDate: _startDate,
            endDate: _endDate,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiReportScreen(
            year: _currentYear,
            month: _currentMonth,
          ),
        ),
      );
    }
  }
}

/// 跳转到 AI 设置页面的包装器
class _SettingsWrapper extends StatelessWidget {
  const _SettingsWrapper();

  @override
  Widget build(BuildContext context) {
    // 直接跳转到设置页面的 AI 设置标签
    // 由于我们的设置页面使用 ListView，直接打开 AiSettingsScreen
    return const AiSettingsScreen();
  }
}
