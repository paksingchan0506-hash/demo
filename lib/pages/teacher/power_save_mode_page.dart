import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/upload_task_manager.dart';

class PowerSaveModePage extends StatefulWidget {
  final double initialBrightness;

  const PowerSaveModePage({super.key, this.initialBrightness = 0.5});

  @override
  State<PowerSaveModePage> createState() => _PowerSaveModePageState();
}

class _PowerSaveModePageState extends State<PowerSaveModePage> {
  static const MethodChannel _processorChannel = MethodChannel(
    'com.example.realvideo/processor',
  );

  StreamSubscription<UploadTaskStatus>? _sub;
  UploadTaskStatus _status = UploadTaskManager().currentStatus;

  double _brightness = 0.5;
  int _activePointers = 0;
  double _twoFingerUp = 0;

  @override
  void initState() {
    super.initState();
    _brightness = widget.initialBrightness;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _setKeepScreenOn(true);
      await _setBrightness(_brightness);
    });
    _sub = UploadTaskManager().statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _setBrightness(-1);
    _setKeepScreenOn(false);
    super.dispose();
  }

  Future<void> _setBrightness(double brightness) async {
    try {
      await _processorChannel.invokeMethod<bool>('setScreenBrightness', {
        'brightness': brightness,
      });
    } catch (_) {}
  }

  Future<void> _setKeepScreenOn(bool enabled) async {
    try {
      await _processorChannel.invokeMethod<bool>('setKeepScreenOn', {
        'enabled': enabled,
      });
    } catch (_) {}
  }

  double get _overallPercent => _status.progress.clamp(0.0, 1.0);

  Future<bool> _onWillPop() async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('請使用雙指向上滑動解鎖返回')));
    return false;
  }

  void _tryUnlock() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final percentText = '${(_overallPercent * 100).toStringAsFixed(0)}%';

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Listener(
        onPointerDown: (_) {
          _activePointers += 1;
        },
        onPointerUp: (_) {
          _activePointers = (_activePointers - 1).clamp(0, 10);
          if (_activePointers < 2) _twoFingerUp = 0;
        },
        onPointerCancel: (_) {
          _activePointers = (_activePointers - 1).clamp(0, 10);
          if (_activePointers < 2) _twoFingerUp = 0;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) {
            if (_activePointers < 2) return;
            if (d.delta.dy < 0) {
              _twoFingerUp += -d.delta.dy;
              if (_twoFingerUp >= 140) _tryUnlock();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.battery_saver,
                                color: Colors.amber,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '慳電模式',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '亮度 ${(100 * _brightness).round()}%',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '處理中',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status.message,
                      style: const TextStyle(
                        color: Colors.white54,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '整體進度',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const Spacer(),
                              Text(
                                percentText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: _overallPercent,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.purpleAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '亮度調整',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          '暗',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Slider(
                            value: _brightness,
                            min: 0.0,
                            max: 1.0,
                            divisions: 100,
                            activeColor: Colors.purpleAccent,
                            inactiveColor: Colors.white10,
                            onChanged: (v) async {
                              HapticFeedback.selectionClick();
                              setState(() => _brightness = v);
                              await _setBrightness(v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '亮',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text(
                        '雙指向上滑動解鎖返回上傳頁面',
                        style: TextStyle(color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
