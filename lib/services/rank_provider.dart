import 'package:flutter/material.dart';
import '../services/rank_api_service.dart';

class RankProvider with ChangeNotifier {
  List<dynamic> _topCourses = [];
  List<dynamic> _topTeachers = [];
  bool _isLoading = false;
  String _error = '';

  List<dynamic> get topCourses => _topCourses;
  List<dynamic> get topTeachers => _topTeachers;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> fetchRankings() async {
    _isLoading = true;
    _error = '';
    // 如果需要 Loading 畫面，這裡可以 notifyListeners()
    
    try {
      final result = await RankApiService.getHomeRankings();
      if (result['status'] == 'success') {
        _topCourses = result['data']['courses'];
        _topTeachers = result['data']['teachers'];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}