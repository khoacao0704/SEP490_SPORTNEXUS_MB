import 'package:flutter/material.dart';
import '../../models/sport.dart';

/// Icon hiển thị cho từng môn (giữ giống icon ở các màn hình cũ).
IconData sportIcon(Sport sport) {
  switch (sport) {
    case Sport.badminton:
      return Icons.sports_tennis;
    case Sport.pickleball:
      return Icons.sports_kabaddi;
    case Sport.football:
      return Icons.sports_soccer;
    case Sport.basketball:
      return Icons.sports_basketball;
    case Sport.tennis:
      return Icons.sports_baseball;
  }
}
