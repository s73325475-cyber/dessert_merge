import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import 'app_ui.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppUpdateService service,
  required AppUpdateInfo info,
  bool allowSkip = true,
}) async {
  final manifest = info.manifest;
  await showDialog<void>(
    context: context,
    barrierDismissible: !manifest.forceUpdate,
    builder: (ctx) {
      return _AppUpdateDialog(
        service: service,
        info: info,
        allowSkip: allowSkip && !manifest.forceUpdate,
      );
    },
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({
    required this.service,
    required this.info,
    required this.allowSkip,
  });

  final AppUpdateService service;
  final AppUpdateInfo info;
  final bool allowSkip;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.downloadAndInstall(
        widget.info.manifest,
        onProgress: (_) {
          if (mounted) setState(() {});
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '설치 실패: ${widget.service.lastError ?? e}';
        });
      }
    }
  }

  void _skip() {
    widget.service.skipUpdate(widget.info.manifest.buildNumber);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.info.manifest;
    final notes = m.releaseNotes.trim();

    return PopScope(
      canPop: widget.allowSkip && !_busy,
      child: AlertDialog(
        backgroundColor: const Color(0xff2c1f43),
        title: Text('업데이트', style: AppUi.modalTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '새 버전 v${m.version} (${m.buildNumber})',
                style: AppUi.modalBody.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '현재 v${widget.info.currentVersion} (${widget.info.currentBuild})',
                style: AppUi.dim.copyWith(fontSize: 13),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  notes,
                  style: AppUi.modalBody.copyWith(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: widget.service.downloadProgress > 0
                      ? widget.service.downloadProgress
                      : null,
                  backgroundColor: Colors.white12,
                  color: Colors.amberAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.service.status == AppUpdateStatus.installing
                      ? '설치 화면을 여는 중…'
                      : '다운로드 중… ${(widget.service.downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: AppUi.dim.copyWith(fontSize: 12),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppUi.dim.copyWith(color: Colors.redAccent, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (widget.allowSkip && !_busy)
            TextButton(
              onPressed: _skip,
              child: Text('나중에',
                  style: AppUi.button.copyWith(color: Colors.white70)),
            ),
          TextButton(
            onPressed: _busy ? null : _install,
            child: Text(
              _busy ? '진행 중…' : '업데이트',
              style: AppUi.button.copyWith(color: Colors.amberAccent),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showManualUpdateResult(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xff2c1f43),
      title: Text('업데이트 확인', style: AppUi.modalTitle),
      content: Text(
        message,
        style: AppUi.modalBody.copyWith(
          color: isError ? Colors.redAccent : Colors.white70,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child:
              Text('확인', style: AppUi.button.copyWith(color: Colors.amberAccent)),
        ),
      ],
    ),
  );
}
