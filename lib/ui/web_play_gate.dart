import 'package:flutter/material.dart';

import '../app/app_release_config.dart';
import '../app/web_launch_config.dart';
import '../game/audio.dart';
import 'app_ui.dart';

/// 모바일 브라우저 오디오 정책 + 첫 로딩 체감 개선용 시작 화면.
class WebPlayGate extends StatefulWidget {
  const WebPlayGate({
    super.key,
    required this.audio,
    required this.onStart,
  });

  final AudioManager audio;
  final VoidCallback onStart;

  @override
  State<WebPlayGate> createState() => _WebPlayGateState();
}

class _WebPlayGateState extends State<WebPlayGate> {
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    await widget.audio.unlockForWeb();
    if (!mounted) return;
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    final target = WebLaunchConfig.parseTarget();
    final modeHint = switch (target) {
      WebLaunchTarget.arcade => '아케이드 모드',
      WebLaunchTarget.campaign => '캠페인 모드',
      WebLaunchTarget.menu => '메인 메뉴',
    };

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xff3d2a5c), Color(0xff1a1028)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🍰', style: TextStyle(fontSize: 88)),
                      const SizedBox(height: 12),
                      Text(
                        AppReleaseConfig.appName,
                        style: AppUi.display.copyWith(fontSize: 26),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '디저트를 쏴서 합치는 빌리어드 머지',
                        style: AppUi.dim.copyWith(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: AppUi.hudPanel(radius: 999),
                        child: Text(
                          modeHint,
                          style: AppUi.label.copyWith(color: const Color(0xff9ad0ec)),
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff5b945),
                            foregroundColor: const Color(0xff2c1f43),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: const StadiumBorder(),
                            elevation: 4,
                          ),
                          onPressed: _starting ? null : _start,
                          child: Text(
                            _starting ? '불러오는 중…' : '▶  탭하여 시작',
                            style: AppUi.button.copyWith(
                              fontSize: 18,
                              color: const Color(0xff2c1f43),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '화면을 가로로 두면 조작이 불편할 수 있어요',
                        style: AppUi.dim.copyWith(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
