/// AI 设置页面
///
/// 用户在此页面配置：
/// - DeepSeek API Key（自定义填入，保护隐私）
/// - 模型名称
/// - API 基础地址
/// - 数据脱敏开关

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/ai_report.dart';
import '../services/ai_summary_service.dart';
import '../l10n/l10n.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final AiSummaryService _aiService = AiSummaryService();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  final _apiBaseUrlController = TextEditingController();

  bool _anonymizeData = true;
  bool _isLoading = true;
  bool _isValidating = false;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  String? _validationResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final config = await _aiService.loadConfig();

    _apiKeyController.text = config.apiKey;
    _modelNameController.text = config.modelName;
    _apiBaseUrlController.text = config.apiBaseUrl;
    _anonymizeData = config.anonymizeData;

    setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    final config = AiConfig(
      apiKey: _apiKeyController.text.trim(),
      modelName: _modelNameController.text.trim().isNotEmpty
          ? _modelNameController.text.trim()
          : 'deepseek-v4-flash',
      apiBaseUrl: _apiBaseUrlController.text.trim().isNotEmpty
          ? _apiBaseUrlController.text.trim()
          : 'https://api.deepseek.com/v1',
      anonymizeData: _anonymizeData,
    );

    await _aiService.saveConfig(config);

    if (mounted) {
      context.read<SettingsProvider>().refreshAiConfig();
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.aiSettingsSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _validateApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _validationResult = L10n.tr('请先填入 API Key', 'Please enter API Key first'));
      return;
    }

    setState(() {
      _isValidating = true;
      _validationResult = null;
    });

    final isValid = await _aiService.validateApiKey(key);

    setState(() {
      _isValidating = false;
      _validationResult =
          isValid ? L10n.tr('✅ API Key 验证成功', '✅ API Key valid') : L10n.tr('❌ API Key 验证失败，请检查后重试', '❌ API Key invalid, please check');
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _apiKeyController.text = data.text!;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelNameController.dispose();
    _apiBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.aiSettingsTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveConfig,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(L10n.save),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- 隐私说明卡片 ----
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🔒 隐私保护说明',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '您的 API Key 仅存储在设备本地数据库中，不会上传到任何服务器。'
                                '打卡数据在发送 AI 分析前会进行脱敏处理（去除日期、地址等敏感信息），'
                                '您可以在下方开关控制是否启用脱敏。',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ---- API Key 配置 ----
                const Text(
                  'DeepSeek API 配置',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '推荐使用 DeepSeek 的 deepseek-v4-flash 模型',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),

                // API Key
                TextField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    labelText: L10n.aiSettingsApiKey,
                    hintText: L10n.aiSettingsApiKeyHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureApiKey = !_obscureApiKey),
                          tooltip: _obscureApiKey ? L10n.tr('显示 Key', 'Show Key') : L10n.tr('隐藏 Key', 'Hide Key'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.paste),
                          onPressed: _pasteFromClipboard,
                          tooltip: L10n.tr('从剪贴板粘贴', 'Paste from clipboard'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 验证按钮 + 结果
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isValidating ? null : _validateApiKey,
                      icon: _isValidating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('验证'),
                    ),
                    if (_validationResult != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _validationResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _validationResult!.contains('✅')
                                ? Colors.green
                                : _validationResult!.contains('❌')
                                    ? Colors.red
                                    : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // 模型名称
                TextField(
                  controller: _modelNameController,
                  decoration: const InputDecoration(
                    labelText: '模型名称',
                    hintText: 'deepseek-v4-flash',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.smart_toy),
                    helperText: '默认: deepseek-v4-flash',
                  ),
                ),
                const SizedBox(height: 12),

                // API 基础地址
                TextField(
                  controller: _apiBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'API 基础地址',
                    hintText: 'https://api.deepseek.com/v1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                    helperText: '默认: https://api.deepseek.com/v1',
                  ),
                ),
                const SizedBox(height: 16),

                // ---- 隐私设置 ----
                const Text(
                  '隐私设置',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    title: const Text('数据脱敏'),
                    subtitle: const Text(
                      '发送前去除具体日期、公司名称等敏感信息，推荐开启',
                    ),
                    secondary: const Icon(Icons.shield, color: Colors.green),
                    value: _anonymizeData,
                    onChanged: (v) => setState(() => _anonymizeData = v),
                  ),
                ),

                const SizedBox(height: 24),

                // ---- 底部说明 ----
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💡 使用提示',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _tipItem(
                            '1. 在 DeepSeek 官网 (platform.deepseek.com) 注册并获取 API Key'),
                        _tipItem('2. 将 API Key 粘贴到上方的输入框中'),
                        _tipItem('3. 点击「验证」按钮确认 Key 可用'),
                        _tipItem('4. 点击右上角「保存」按钮保存配置'),
                        _tipItem('5. 返回分析页面，点击「AI 分析」生成报告'),
                        const SizedBox(height: 8),
                        Text(
                          '未配置 API Key 时，AI 分析功能不可用，但不影响其他功能。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
