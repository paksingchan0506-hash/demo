import 'package:flutter/material.dart';

enum CardState { hidden, visible, matched }

class MemoryCardModel {
  final int id;
  final IconData icon;
  CardState state;

  MemoryCardModel({
    required this.id,
    required this.icon,
    this.state = CardState.hidden,
  });
}
