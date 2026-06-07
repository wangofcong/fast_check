import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ai_report.dart';
import '../services/ai_summary_service.dart';
import '../l10n/l10n.dart';

/// AI 总结报告页面
///
/// 展示 AI 生成的工作习惯分析报告。
/// 支持年月（月度）和日期范围（自定义）两种模式。
/// 进入页面时显示上一次生成的结果（如果有），
/// 用户点击「生成」按钮后才调用 API 生成新报告。
class AiReportScreen extends StatefulWidget {
  final int? year;
  final int? month;
  final String? startDate;
  final String? endDate;

  const AiReportScreen({
    super.key,
    this.year,
    this.month,
    this.startDate,
    this.endDate,
  }) : assert(
          (year != null && month != null) ||
              (startDate != null && endDate != null),
          '必须提供 (year, month) 或 (startDate, endDate)',
        );

  @override
  State<AiReportScreen> createState() => _AiReportScreenState();
}

class _AiReportScreenState extends State<AiReportScreen> {
  final AiSummaryService _aiService = AiSummaryService();
  AiReport? _report;
  bool _isLoadingCache = true;
  bool _isGenerating = false;
  String? _error;

  /// 是否为日期范围模式
  bool get _isPeriodMode =>
      widget.startDate != null && widget.endDate != null;

  String get _periodLabel {
    if (_isPeriodMode) {
      return '${widget.startDate} ~ ${widget.endDate}';
    }
    return '${widget.year}年${widget.month}月';
  }

  String get _reportType => _isPeriodMode ? 'period' : 'monthly';

  @override
  void initState() {
    super.initState();
    _loadCachedReport();
  }

  /// 加载缓存的报告（不调 API）
  Future<void> _loadCachedReport() async {
    setState(() {
      _isLoadingCache = true;
      _error = null;
    });

    try {
      final cached =
          await _aiService.loadCachedReport(_reportType, _periodLabel);
      if (mounted) {
        setState(() {
          _report = cached;
          _isLoadingCache = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingCache = false;
        });
      }
    }
  }

  /// 用户主动点击生成
  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    AiReport report;
    if (_isPeriodMode) {
      report = await _aiService.generatePeriodReport(
        widget.startDate!,
        widget.endDate!,
      );
    } else {
      report = await _aiService.generateMonthlyReport(
        widget.year!,
        widget.month!,
      );
    }

    if (mounted) {
      setState(() {
        _report = report;
        _isGenerating = false;
        if (!report.isSuccess) {
          _error = report.error;
        }
      });
    }
  }

  Color _findingColor(String type) {
    switch (type) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _findingIcon(String type) {
    switch (type) {
      case 'positive':
        return Icons.thumb_up_alt;
      case 'negative':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${L10n.aiReportTitle} - $_periodLabel'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 加载缓存中
    if (_isLoadingCache) {
      return const Center(child: CircularProgressIndicator());
    }

    // 已有报告（缓存或刚生成）
    if (_report != null && _report!.isSuccess) {
      return RefreshIndicator(
        onRefresh: _loadCachedReport,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            // --- 顶部操作栏 ---
            _buildActionBar(),
            const SizedBox(height: 12),

            // ---- 概况卡片 ----
            if (_report!.overview != null) _buildOverviewCard(),
            if (_report!.overview != null) const SizedBox(height: 12),

            // ---- 评分区域 ----
            if (_report!.scores.isNotEmpty) ...[
              _buildScoresSection(),
              const SizedBox(height: 12),
            ],

            // ---- 关键发现 ----
            if (_report!.findings.isNotEmpty) ...[
              _buildFindingsSection(),
              const SizedBox(height: 12),
            ],

            // ---- 改进建议 ----
            if (_report!.suggestions.isNotEmpty) ...[
              _buildSuggestionsSection(),
              const SizedBox(height: 12),
            ],

            // ---- 底部信息 ----
            _buildFooter(),

            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // 无缓存或生成失败 → 显示生成入口
    return _buildGenerateView();
  }

  // ==================================================================
  //  顶部操作栏（重新生成 + 时间信息）
  // ==================================================================

  Widget _buildActionBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.refresh,
                size: 16, color: _isGenerating ? Colors.grey : Colors.blue),
            const SizedBox(width: 8),
                          Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _report!.generatedAt.length >= 16
                          ? '${L10n.aiReportGeneratedAt}: ${_report!.generatedAt.substring(0, 16).replaceAll('T', ' ')}'
                          : L10n.aiReportCacheFound,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (_report!.findings.isNotEmpty)
                      Text(
                        '${_report!.findings.length} ${L10n.tr('条发现', 'findings')} · ${_report!.suggestions.length} ${L10n.tr('条建议', 'suggestions')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _isGenerating ? null : _generateReport,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_isGenerating ? L10n.aiReportGenerating : L10n.aiReportRegenerate),
              ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  //  生成入口（无缓存时显示）
  // ==================================================================

  Widget _buildGenerateView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 56,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                L10n.aiReportTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                L10n.tr('基于 $_periodLabel 的打卡数据，\n生成个性化工作习惯总结与改进建议',
                    'Based on punch data from $_periodLabel,\ngenerate personalized work habit analysis'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600],
                    height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateReport,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                      _isGenerating ? L10n.aiReportGenerating : L10n.aiReportGenerate),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                L10n.tr('数据经过脱敏处理后发送至 DeepSeek API',
                    'Data is anonymized before sending to DeepSeek API'),
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              // 底部留白确保键盘/导航栏不遮挡
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  //  概况卡片
  // ==================================================================

  Widget _buildOverviewCard() {
    final ov = _report!.overview!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  L10n.tr('月度概况', 'Monthly Overview'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ov.summary,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              children: [
                _miniStat('出勤', '${ov.attendedDays}/${ov.totalWorkDays}天',
                    Colors.blue),
                _miniStat('迟到', '${ov.lateCount}次',
                    ov.lateCount > 0 ? Colors.red : Colors.green),
                _miniStat('加班', '${ov.overtimeDays}天',
                    ov.overtimeDays > 0 ? Colors.deepOrange : Colors.grey),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _miniStat('平均到岗', ov.avgArrival, Colors.indigo),
                _miniStat('平均离岗', ov.avgDeparture, Colors.purple),
                _miniStat('平均工时', ov.avgWorkDuration, Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  //  评分区域
  // ==================================================================

  Widget _buildScoresSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '综合评分',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ..._report!.scores.map((score) => _buildScoreRow(score)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(AiScore score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                score.name,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < score.starCount ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score.percentage,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            score.label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  //  关键发现
  // ==================================================================

  Widget _buildFindingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.search, size: 18, color: Colors.teal),
                SizedBox(width: 6),
                Text(
                  '关键发现',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._report!.findings.map((f) => _buildFindingItem(f)),
          ],
        ),
      ),
    );
  }

  Widget _buildFindingItem(AiFinding finding) {
    final color = _findingColor(finding.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _findingIcon(finding.type),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  finding.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  //  改进建议
  // ==================================================================

  Widget _buildSuggestionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber),
                SizedBox(width: 6),
                Text(
                  '改进建议',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._report!.suggestions.asMap().entries.map(
                  (entry) =>
                      _buildSuggestionItem(entry.key + 1, entry.value),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(int index, AiSuggestion suggestion) {
    final priorityColors = <int, Color>{
      1: Colors.red,
      2: Colors.deepOrange,
      3: Colors.orange,
      4: Colors.amber,
      5: Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (priorityColors[suggestion.priority] ?? Colors.grey)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: priorityColors[suggestion.priority] ?? Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  //  底部信息
  // ==================================================================

  Widget _buildFooter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 14, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '报告生成时间: ${_report!.generatedAt.substring(0, 19).replaceAll('T', ' ')}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: '复制报告文本',
              onPressed: _copyReportText,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              tooltip: '重新生成',
              onPressed: _isGenerating ? null : _generateReport,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyReportText() async {
    if (_report == null) return;
    final sb = StringBuffer();
    sb.writeln('🤖 AI 工作习惯分析报告');
    sb.writeln(_periodLabel);
    sb.writeln('---');

    if (_report!.overview != null) {
      sb.writeln('\n📋 概况');
      sb.writeln(_report!.overview!.summary);
    }

    if (_report!.findings.isNotEmpty) {
      sb.writeln('\n📌 关键发现');
      for (final f in _report!.findings) {
        sb.writeln('- ${f.title}: ${f.description}');
      }
    }

    if (_report!.suggestions.isNotEmpty) {
      sb.writeln('\n💡 改进建议');
      for (final s in _report!.suggestions) {
        sb.writeln('- ${s.title}: ${s.description}');
      }
    }

    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('报告已复制到剪贴板'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
