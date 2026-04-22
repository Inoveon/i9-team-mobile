import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _urlController;
  bool _isSaving = false;
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await AppConfig.getBackendUrl();
    if (mounted) _urlController.text = url;
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _feedbackMessage = '❌ URL não pode estar vazia');
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _feedbackMessage = '❌ URL deve começar com http:// ou https://');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await AppConfig.setBackendUrl(url);
      await AppConfig.clearJwt(); // força novo login com nova URL
      ApiClient.reset();          // reseta instância do Dio
      setState(() => _feedbackMessage = '✅ URL salva! Conectando...');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _feedbackMessage = '❌ Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        title: Text('Configurações', style: AppTextStyles.heading1),
        iconTheme: const IconThemeData(color: AppColors.neonBlue),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('URL do Backend', style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            Text('Configure o endereço do servidor backend.', style: AppTextStyles.bodyMuted),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              enabled: !_isSaving,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'http://localhost:4020',
                hintStyle: AppTextStyles.bodyMuted,
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text('Salvar', style: AppTextStyles.label.copyWith(color: Colors.white)),
              ),
            ),
            if (_feedbackMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _feedbackMessage!.startsWith('✅')
                      ? AppColors.neonGreen.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_feedbackMessage!, style: AppTextStyles.body),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            Text('Avançado', style: AppTextStyles.heading2),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code, color: AppColors.neonPurple),
              title: Text('Editor de teams.json', style: AppTextStyles.body),
              subtitle: Text(
                'GET+PUT /teams/config + resync',
                style: AppTextStyles.label,
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => context.push('/config'),
            ),
          ],
        ),
      ),
    );
  }
}
