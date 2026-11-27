import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/strings/player_tournament_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/player_tournament_repository.dart';
import '../../models/tournament_listing.dart';
import '../../theme/app_colors.dart';

/// Vé QR check-in của tôi cho một nội dung giải (mã tĩnh).
class TournamentTicketScreen extends StatefulWidget {
  final String divisionId;

  /// Tắt tự hỏi lại (test).
  final bool autoRefresh;

  const TournamentTicketScreen({
    super.key,
    required this.divisionId,
    this.autoRefresh = true,
  });

  @override
  State<TournamentTicketScreen> createState() => _TournamentTicketScreenState();
}

class _TournamentTicketScreenState extends State<TournamentTicketScreen> {
  /// Như Web: hỏi lại khoảng 15 giây một lần tới khi đã điểm danh.
  static const Duration refreshEvery = Duration(seconds: 15);

  TournamentTicket? _ticket;
  String? _error;
  bool _checkedIn = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoRefresh) {
      _timer = Timer.periodic(refreshEvery, (_) => _load(quiet: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Đã điểm danh: theo vé, hoặc theo "Giải của tôi" khi vé BE không ghi.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _error = null);
    final repo = AppRepositories.playerTournament;
    try {
      final ticket = await repo.getTicket(widget.divisionId);
      var checked = ticket.isCheckedIn;
      if (!checked) {
        try {
          checked = (await repo.getMyRegistrations()).any(
            (r) => r.divisionId == widget.divisionId && r.isCheckedIn,
          );
        } catch (_) {
          // giữ theo vé
        }
      }
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _checkedIn = checked;
      });
      if (checked) _timer?.cancel();
    } catch (e) {
      if (mounted && !quiet) {
        setState(
          () => _error = e is TournamentException
              ? e.message
              : PlayerTournamentStrings.loadError,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          PlayerTournamentStrings.ticketTitle,
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text(PlayerTournamentStrings.retry),
                  ),
                ],
              ),
            )
          : t == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.tournamentName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMain,
                        ),
                      ),
                      if (t.facilityName.isNotEmpty)
                        Text(
                          t.facilityName,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _checkedIn ? 0.15 : 1,
                            child: QrImageView(
                              data: t.qrCode,
                              size: 220,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          if (_checkedIn)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      PlayerTournamentStrings.checkedIn,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        t.qrCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (t.teamName != null)
                        Text(
                          t.teamName!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  PlayerTournamentStrings.ticketHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}
