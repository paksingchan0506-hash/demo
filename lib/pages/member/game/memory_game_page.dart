import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import 'memory_game_controller.dart';
import 'memory_card_model.dart';
import '../../../services/mini_game_access_service.dart';

class MemoryGamePage extends StatefulWidget {
  const MemoryGamePage({super.key});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  final MemoryGameController _controller = MemoryGameController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playBgm();

    // 初始化遊戲結束回調
    _controller.onGameFinished = (won, stars) async {
      if (!mounted) return;
      if (stars > 0) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        int awardPoints = stars * 5;
        try {
          await userProvider.addPoints(awardPoints, "記憶配對獎勵：$stars 星級");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('恭喜獲得 $awardPoints 積分！'),
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
    };
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _playBgm() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.25);
      await _audioPlayer.play(AssetSource('audio/bgm.mp3'));
    } catch (e) {
      debugPrint('bgm error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('記憶配對')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_controller.status == GameStatus.idle) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '玩法說明',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '先在記憶倒數期間觀察卡牌位置。倒數結束後於時間限制內翻牌，兩張圖示相同即配對成功，可獲得分數；完成全部配對即獲勝。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '評分規則：配對成功得 2 分，分數越高星星越多。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final allowed = await MiniGameAccessService()
                            .ensureCanPlay(context, MiniGameId.memory);
                        if (!allowed) return;

                        // 開始遊戲
                        _controller.startGame();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        textStyle: const TextStyle(fontSize: 24),
                      ),
                      child: const Text('開始遊戲'),
                    ),
                  ),
                ],
              ),
            );
          }

          if (_controller.status == GameStatus.finished) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _controller.isWon ? '你贏了！' : '遊戲結束',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return Icon(
                        index < _controller.stars
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 48,
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '分數：${_controller.score}',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _controller.status == GameStatus.memorizing
                          ? '記憶倒數：${_controller.currentMemorizeTime}'
                          : '剩餘時間：${_controller.currentTime}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        3,
                        (index) => Icon(
                          Icons.star,
                          color: index < _controller.stars
                              ? Colors.amber
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_controller.status == GameStatus.memorizing)
                const LinearProgressIndicator(),

              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                        itemCount: _controller.cards.length,
                        itemBuilder: (context, index) {
                          final card = _controller.cards[index];
                          return GestureDetector(
                            onTap: () => _controller.onCardTap(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: card.state == CardState.hidden
                                    ? Colors.blue
                                    : (card.state == CardState.matched
                                          ? Colors.green
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Center(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return card.state == CardState.hidden
                                        ? Icon(
                                            Icons.question_mark,
                                            color: Colors.white,
                                            size: constraints.maxWidth * 0.6,
                                          )
                                        : Icon(
                                            card.icon,
                                            size: constraints.maxWidth * 0.7,
                                            color: Colors.black87,
                                          );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
