import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../../../services/mini_game_access_service.dart';

class PieSliceClipper extends CustomClipper<Path> {
  final double sliceAngle;

  PieSliceClipper(this.sliceAngle);

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 * 1.1;

    final path = ui.Path();

    path.moveTo(center.dx, center.dy);

    path.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      -sliceAngle / 2,
      sliceAngle,
      false,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(PieSliceClipper oldClipper) {
    return oldClipper.sliceAngle != sliceAngle;
  }
}

class RouletteGamePage extends StatefulWidget {
  const RouletteGamePage({super.key});

  @override
  State<RouletteGamePage> createState() => _RouletteGamePageState();
}

class _RouletteGamePageState extends State<RouletteGamePage>
    with SingleTickerProviderStateMixin {
  bool _isSpinning = false;
  double _rotationAngle = 0.0;
  String? _resultText;
  bool _showResult = false;
  bool _resultWindowVisible = false;
  bool _resultButtonPressed = false;

  late AnimationController _rotationController;
  Animation<double>? _angleAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  final List<String> rewards = [
    '50積分',
    '30積分',
    '20積分',
    '15積分',
    '10積分',
    '5積分',
    '謝謝參與',
    '再試一次',
  ];

  Future<void> _handleReward(String reward, UserProvider userProvider) async {
    if (reward == "謝謝參與") {
      return;
    } else if (reward == "再試一次") {
      return;
    } else if (reward.contains("積分")) {
      int amount = int.parse(reward.replaceAll(RegExp(r'[^0-9]'), ''));
      try {
        await userProvider.addPoints(amount, "輪盤中獎：$reward");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('恭喜獲得 $amount 積分！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('積分同步失敗，請檢查網路連線'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _startSpinning({bool isFreeSpin = false}) async {
    if (_isSpinning) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!isFreeSpin) {
      final allowed = await MiniGameAccessService()
          .ensureCanPlay(context, MiniGameId.roulette);
      if (!allowed) return;
    }

    setState(() {
      _isSpinning = true;
      _showResult = false;
      _resultWindowVisible = false;
    });

    HapticFeedback.mediumImpact();

    final random = Random();
    final rewardIndex = random.nextInt(rewards.length);
    final sectorAngle = 2 * pi / rewards.length;
    double targetSectorPosition = rewardIndex * sectorAngle;
    double targetRotation = -pi / 2 - targetSectorPosition;
    double fullRotations = 2 * pi * (5 + random.nextInt(3));
    double targetAngle = fullRotations + targetRotation;

    _rotationController.reset();
    _angleAnimation =
        Tween<double>(
          begin: _rotationAngle % (2 * pi),
          end: targetAngle,
        ).animate(
          CurvedAnimation(
            parent: _rotationController,
            curve: Curves.easeOutQuart,
          ),
        );

    // 由 AnimatedBuilder 驅動視覺更新，避免每幀 setState

    _angleAnimation!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final reward = rewards[rewardIndex];
        _handleReward(reward, userProvider);
        setState(() {
          _isSpinning = false;
          _resultText = reward;
          _showResult = true;
          _rotationAngle = _angleAnimation!.value;
        });
        HapticFeedback.selectionClick();
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() => _resultWindowVisible = true);
        });
      }
    });

    _rotationController.forward();
  }

  void _closeResult() {
    setState(() {
      _resultWindowVisible = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() {
          _showResult = false;
          _resultText = null;
          _rotationAngle = 0.0;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('幸運輪盤'),
        backgroundColor: Colors.grey[800],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1000.0),
                  border: Border.all(color: Colors.grey.shade300, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(180.0),
                                boxShadow: null,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: AnimatedBuilder(
                                      animation:
                                          _angleAnimation ??
                                          _rotationController,
                                      builder: (context, child) {
                                        final angle =
                                            (_angleAnimation?.value ??
                                            _rotationAngle);
                                        return AnimatedRotation(
                                          turns: angle / (2 * pi),
                                          duration: Duration.zero,
                                          child: child,
                                        );
                                      },
                                      child: _buildRouletteWheel(),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 5,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.arrow_upward,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: AnimatedScale(
                              scale: _isSpinning ? 0.95 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: ElevatedButton(
                                onPressed: _isSpinning ? null : _startSpinning,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSpinning
                                      ? Colors.grey
                                      : Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 60,
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                  elevation: 5,
                                  shadowColor: Colors.redAccent.withOpacity(
                                    0.3,
                                  ),
                                ),
                                child: Text(
                                  _isSpinning ? '旋轉中...' : '開始旋轉',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showResult && _resultText != null)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.bounceOut,
                    width: _resultWindowVisible
                        ? MediaQuery.of(context).size.width * 0.85
                        : 0,
                    height: _resultWindowVisible
                        ? MediaQuery.of(context).size.height * 0.4
                        : 0,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20.0,
                          spreadRadius: 5.0,
                        ),
                      ],
                    ),
                    child: _resultWindowVisible ? _buildResultWindow() : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultWindow() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final isFreeSpin = _resultText == '再試一次';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Text(
            '恭喜您獲得',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              _resultText!,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Text(
            '目前積分：${userProvider.currentUser?.points ?? 0} PTS',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Container(
          height: 8,
          width: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 30),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: AnimatedScale(
            scale: _resultButtonPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: GestureDetector(
              onTapDown: (details) {
                setState(() {
                  _resultButtonPressed = true;
                });
              },
              onTapUp: (details) {
                setState(() {
                  _resultButtonPressed = false;
                });
                _closeResult();
              },
              onTapCancel: () {
                setState(() {
                  _resultButtonPressed = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 60,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  '關閉',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.blue,
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isFreeSpin)
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: ElevatedButton(
              onPressed: () {
                _closeResult();
                Future.delayed(const Duration(milliseconds: 350), () {
                  _startSpinning(isFreeSpin: true);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                '再轉一次（免費）',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRouletteWheel() {
    List<Widget> segments = [];
    double angle = 0.0;
    double sliceAngle = 2 * pi / rewards.length;

    for (int i = 0; i < rewards.length; i++) {
      segments.add(
        Transform.rotate(
          angle: angle,
          child: ClipPath(
            clipper: PieSliceClipper(sliceAngle),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: _getSegmentColor(i),
              child: Transform.rotate(
                angle: pi / 2,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 95.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        rewards[i],
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: const [
                            Shadow(
                              color: Colors.white,
                              blurRadius: 2,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      angle += sliceAngle;
    }

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Stack(children: [...segments]),
        ),
        Container(
          margin: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            border: null,
            boxShadow: null,
          ),
        ),
      ],
    );
  }

  Color _getSegmentColor(int index) {
    List<Color> colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.yellow[600]!,
      Colors.teal,
    ];
    return colors[index % colors.length];
  }
}
