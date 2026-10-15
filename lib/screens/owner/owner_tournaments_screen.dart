import 'package:flutter/material.dart';

import '../../core/strings/common_strings.dart';
import '../../core/strings/owner_tournament_strings.dart';
import '../../data/app_repositories.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../widgets/tournament/tournament_card.dart';
import 'owner_tournament_detail_screen.dart';
import 'tournament_form_screen.dart';

/// Giải do Chủ sân tổ chức, nút tạo giải mới.
class OwnerTournamentsScreen extends StatefulWidget {
  const OwnerTournamentsScreen({super.key});

  @override
  State<OwnerTournamentsScreen> createState() => _OwnerTournamentsScreenState();
}

class _OwnerTournamentsScreenState extends State<OwnerTournamentsScreen> {
  List<Tournament> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await AppRepositories.organizer.getOrganizedTournaments();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(CommonStrings.genericError), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Tournament t) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerTournamentDetailScreen(tournament: t)));
    _load();
  }

  Future<void> _create() async {
    final created = await Navigator.push<Tournament>(
      context,
      MaterialPageRoute(builder: (_) => const TournamentFormScreen()),
    );
    if (created != null && mounted) await _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerTournamentStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create-tournament',
        onPressed: _create,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(OwnerTournamentStrings.create),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.cardBorder),
                          SizedBox(height: 12),
                          Text(OwnerTournamentStrings.empty, style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                            OwnerTournamentStrings.emptyHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final t in _items) TournamentCard(tournament: t, now: now, onTap: () => _open(t)),
                ],
              ),
      ),
    );
  }
}
