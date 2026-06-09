import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'memory_card_model.dart';

enum GameStatus { idle, memorizing, playing, finished }

class MemoryGameController extends ChangeNotifier {
  List<MemoryCardModel> cards = [];
  GameStatus status = GameStatus.idle;

  int score = 0;
  int totalPairs = 8;
  int matchedPairs = 0;
  bool isWon = false;

  int timeLimit = 15;
  int currentTime = 15;
  Timer? _timer;

  int memorizeTime = 5;
  int currentMemorizeTime = 5;

  int? _firstSelectedIndex;
  bool _isProcessingMatch = false;

  void Function(bool won, int stars)? onGameFinished;

  int get stars {
    if (score >= 16) return 3;
    if (score >= 10) return 2;
    if (score >= 6) return 1;
    return 0;
  }

  void startGame() {
    _resetGame();
    _generateCards();
    status = GameStatus.memorizing;
    notifyListeners();
    _startMemorizeTimer();
  }

  void _resetGame() {
    score = 0;
    matchedPairs = 0;
    currentTime = timeLimit;
    currentMemorizeTime = memorizeTime;
    status = GameStatus.idle;
    _firstSelectedIndex = null;
    _isProcessingMatch = false;
    _timer?.cancel();
  }

  void _generateCards() {
    List<IconData> icons = [
      Icons.ac_unit,
      Icons.access_alarm,
      Icons.accessibility,
      Icons.account_balance,
      Icons.adb,
      Icons.add_a_photo,
      Icons.adjust,
      Icons.agriculture,
    ];

    List<MemoryCardModel> tempCards = [];
    for (int i = 0; i < 8; i++) {
      tempCards.add(
        MemoryCardModel(id: i, icon: icons[i], state: CardState.visible),
      );
      tempCards.add(
        MemoryCardModel(id: i, icon: icons[i], state: CardState.visible),
      );
    }

    tempCards.shuffle(Random());
    cards = tempCards;
  }

  void _startMemorizeTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentMemorizeTime > 0) {
        currentMemorizeTime--;
        notifyListeners();
      } else {
        _timer?.cancel();
        _startPlayPhase();
      }
    });
  }

  void _startPlayPhase() {
    for (var card in cards) {
      card.state = CardState.hidden;
    }
    status = GameStatus.playing;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (currentTime > 0) {
        currentTime--;
        notifyListeners();
      } else {
        _endGame(false);
      }
    });
  }

  void onCardTap(int index) {
    if (status != GameStatus.playing || _isProcessingMatch) return;
    if (cards[index].state != CardState.hidden) return;

    cards[index].state = CardState.visible;
    notifyListeners();

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = index;
    } else {
      _checkMatch(_firstSelectedIndex!, index);
    }
  }

  void _checkMatch(int index1, int index2) async {
    _isProcessingMatch = true;

    if (cards[index1].id == cards[index2].id) {
      cards[index1].state = CardState.matched;
      cards[index2].state = CardState.matched;
      score += 2;
      matchedPairs++;

      _firstSelectedIndex = null;
      _isProcessingMatch = false;
      notifyListeners();

      if (matchedPairs == totalPairs) {
        _endGame(true);
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));

      if (status != GameStatus.playing) return;

      cards[index1].state = CardState.hidden;
      cards[index2].state = CardState.hidden;

      _firstSelectedIndex = null;
      _isProcessingMatch = false;
      notifyListeners();
    }
  }

  void _endGame(bool won) {
    isWon = won;
    _timer?.cancel();
    status = GameStatus.finished;
    notifyListeners();
    if (onGameFinished != null) {
      onGameFinished!(won, stars);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
