import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../shared/widgets/glass_container.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await AppConfig.getBackendUrl();
    _urlController.text = url;
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await AppConfig.setBackendUrl(url);
    ApiClient.reset();
    WsClient.disconnect();
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Configuracoes', style: AppTextStyles.heading1),
        iconTheme: const IconThemeData(color: AppColors.neonBlue),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('URL do Backend', style: AppTextStyles.heading2),
              const SizedBox(height: 4),
              Text('Ex: http://192.168.1.100:3100', style: AppTextStyles.bodyMuted),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                style: AppTextStyles.body,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: AppConfig.defaultUrl,
                  hintStyle: AppTextStyles.bodyMuted,
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.neonBlue, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  GlassButton(
                    label: _saved ? 'Salvo!' : 'Salvar',
                    icon: _saved ? Icons.check : Icons.save_outlined,
                    color: _saved ? AppColors.neonGreen : AppColors.neonBlue,
                    onPressed: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
