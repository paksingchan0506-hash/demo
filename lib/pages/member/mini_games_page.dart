import 'package:flutter/material.dart';
import 'game/roulette_game_page.dart';
import 'game/memory_game_page.dart';

class MiniGamesPage extends StatelessWidget {
  const MiniGamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('小遊戲'),
        backgroundColor: Colors.grey[800],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '選擇遊戲',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '玩遊戲賺取積分，每天都有機會獲得獎勵！',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 20),

          // 幸運輪盤遊戲卡片
          _buildGameCard(
            '幸運輪盤',
            '轉動輪盤贏取驚喜獎勵',
            'assets/roulette_icon.png',
            Colors.red,
            '首次免費，之後需觀看廣告',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RouletteGamePage(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 記憶配對遊戲卡片
          _buildGameCard(
            '記憶配對',
            '在時間內完成所有配對挑戰',
            'assets/memory_icon.png',
            Colors.blue,
            '首次免費，之後需觀看廣告',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemoryGamePage()),
              );
            },
          ),
          const SizedBox(height: 16),

          // 更多遊戲可以在此添加
          _buildComingSoonCard('更多遊戲開發中...', Icons.build, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildGameCard(
    String title,
    String description,
    String imagePath,
    Color color,
    String cost,
    VoidCallback onTap,
  ) {
    return Card(
      color: Colors.grey[800],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.casino, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cost,
                      style: TextStyle(color: Colors.orange[300], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonCard(String text, IconData icon, Color color) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(text, style: TextStyle(color: color, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
