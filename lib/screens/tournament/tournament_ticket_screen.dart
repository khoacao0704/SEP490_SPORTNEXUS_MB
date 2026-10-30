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

  const TournamentTicketScreen({super.key, required this.divisionId});

  @override
  State<TournamentTicketScreen> createState() => _TournamentTicketScreenState();
}

class _TournamentTicketScreenState extends State<TournamentTicketScreen> {
  TournamentTicket? _ticket;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final ticket = await AppRepositories.playerTournament.getTicket(widget.divisionId);
      if (mounted) setState(() => _ticket = ticket);
    } catch (e) {
      if (mounted) setState(() => _error = e is TournamentException ? e.message : PlayerTournamentStrings.loadError);
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
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text(PlayerTournamentStrings.retry)),
                ],
              ),
            )
          : t == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
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
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      if (t.facilityName.isNotEmpty)
                        Text(t.facilityName, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      QrImageView(data: t.qrCode, size: 220, backgroundColor: Colors.white),
                      const SizedBox(height: 8),
                      SelectableText(
                        t.qrCode,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                      const SizedBox(height: 12),
                      Text(t.fullName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      if (t.teamName != null) Text(t.teamName!, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  PlayerTournamentStrings.ticketHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }
}
