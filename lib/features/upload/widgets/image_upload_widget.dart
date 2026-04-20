import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/toast_stack.dart';
import '../services/image_upload_service.dart';
import '../models/upload_result.dart';

typedef OnUploadSuccess = Future<void> Function(UploadResult result);

class ImageUploadWidget extends ConsumerStatefulWidget {
  const ImageUploadWidget({
    super.key,
    required this.onUploadSuccess,
    this.onUploadError,
  });

  final OnUploadSuccess onUploadSuccess;
  final void Function(String error)? onUploadError;

  @override
  ConsumerState<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends ConsumerState<ImageUploadWidget> {
  bool _isUploading = false;
  UploadResult? _lastUpload;

  Future<void> _handleUpload(Future<dynamic> Function() pickFn) async {
    setState(() => _isUploading = true);
    Navigator.pop(context); // Fecha bottom sheet

    try {
      final file = await pickFn();
      if (file == null) {
        setState(() => _isUploading = false);
        return;
      }

      // Upload
      final result = await ImageUploadService.uploadImage(file);
      if (result != null) {
        setState(() => _lastUpload = result);
        await widget.onUploadSuccess(result);

        ref
            .read(toastProvider.notifier)
            .success('Imagem enviada: ${result.filename}');
      } else {
        widget.onUploadError?.call('Erro ao fazer upload da imagem');
        ref
            .read(toastProvider.notifier)
            .error('Erro ao fazer upload da imagem');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _UploadOptions(
        onClipboard: () => _handleUpload(ImageUploadService.pickFromClipboard),
        onGallery: () => _handleUpload(ImageUploadService.pickFromGallery),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_lastUpload != null) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _lastUpload!.url,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: AppColors.border,
                      child: const Icon(Icons.image, color: AppColors.neonBlue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _lastUpload!.filename,
                        style: AppTextStyles.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${(_lastUpload!.size / 1024).toStringAsFixed(2)} KB',
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GestureDetector(
            onTap: _showUploadOptions,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.1),
                border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isUploading ? Icons.cloud_upload : Icons.add_photo_alternate_outlined,
                    color: AppColors.neonBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUploading ? 'Enviando...' : 'Adicionar Imagem',
                    style: AppTextStyles.label.copyWith(color: AppColors.neonBlue),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadOptions extends StatefulWidget {
  const _UploadOptions({
    required this.onClipboard,
    required this.onGallery,
  });

  final VoidCallback onClipboard;
  final VoidCallback onGallery;

  @override
  State<_UploadOptions> createState() => _UploadOptionsState();
}

class _UploadOptionsState extends State<_UploadOptions> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF080B14).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                top: BorderSide(color: AppColors.neonBlue.withOpacity(0.2)),
                left: BorderSide(color: AppColors.neonBlue.withOpacity(0.2)),
                right: BorderSide(color: AppColors.neonBlue.withOpacity(0.2)),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.1),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'SELECIONE UMA FONTE:',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.neonBlue,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                _UploadOption(
                  icon: Icons.assignment_outlined,
                  label: 'Da área de transferência',
                  onTap: widget.onClipboard,
                ),
                _UploadOption(
                  icon: Icons.image_outlined,
                  label: 'Da galeria',
                  onTap: widget.onGallery,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadOption extends StatefulWidget {
  const _UploadOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_UploadOption> createState() => _UploadOptionState();
}

class _UploadOptionState extends State<_UploadOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? AppColors.neonBlue.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
            color: _hovered ? AppColors.neonBlue.withOpacity(0.12) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: AppColors.neonBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.body.copyWith(
                    color: const Color(0xFFe2e8f0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
