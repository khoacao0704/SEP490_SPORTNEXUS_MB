import 'package:flutter/material.dart';

import '../../core/strings/owner_shop_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/facility.dart';
import '../../models/owner_promotion.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/owner_badges.dart';
import '../../widgets/owner/owner_cancel_dialog.dart' show ownerErrorMessage;
import '../../widgets/owner/slot_pickers.dart' show showOwnerSnack;

BadgeTone _tone(PromotionStatus s) => switch (s) {
      PromotionStatus.scheduled => BadgeTone.amber,
      PromotionStatus.active => BadgeTone.green,
      PromotionStatus.cancelled => BadgeTone.red,
      _ => BadgeTone.gray,
    };

/// Quảng bá (như Web: OwnerPromotions.jsx): gói đang bán, mua gói trừ ví, lượt đã mua.
/// Mobile chỉ làm gói cho cơ sở (phần giải đấu chưa đụng tới).
class OwnerPromotionsScreen extends StatefulWidget {
  const OwnerPromotionsScreen({super.key});

  @override
  State<OwnerPromotionsScreen> createState() => _OwnerPromotionsScreenState();
}

class _OwnerPromotionsScreenState extends State<OwnerPromotionsScreen> {
  List<PromotionPackage>? _packages;
  String? _packagesError;
  List<OwnerPromotion>? _mine;
  String? _mineError;
  List<Facility> _facilities = [];
  bool _activeOnly = false;

  @override
  void initState() {
    super.initState();
    AppRepositories.owner.getMyFacilities().then((v) {
      if (mounted) setState(() => _facilities = v);
    }, onError: (_) {});
    _loadPackages();
    _loadMine();
  }

  Future<void> _loadPackages() async {
    try {
      final list = await AppRepositories.owner.getPromotionPackages();
      if (mounted) setState(() => _packages = list);
    } catch (e) {
      if (mounted) setState(() => _packagesError = ownerErrorMessage(e));
    }
  }

  Future<void> _loadMine() async {
    try {
      final list = await AppRepositories.owner.getMyPromotions(activeOnly: _activeOnly);
      if (mounted) {
        setState(() {
          _mine = list;
          _mineError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _mineError = ownerErrorMessage(e));
    }
  }

  Future<void> _buy(PromotionPackage pkg) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PurchaseSheet(pkg: pkg, facilities: _facilities),
    );
    if (done == true && mounted) {
      showOwnerSnack(context, OwnerPromoStrings.bought(pkg.name));
      _loadMine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          OwnerPromoStrings.title,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_loadPackages(), _loadMine()]),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(OwnerPromoStrings.subtitle, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _section(OwnerPromoStrings.packagesTitle, null),
            const SizedBox(height: 8),
            ..._packageList(),
            const SizedBox(height: 20),
            _section(
              OwnerPromoStrings.mineTitle,
              FilterChip(
                label: const Text(OwnerPromoStrings.activeOnly),
                selected: _activeOnly,
                selectedColor: AppColors.lightGreen,
                onSelected: (v) {
                  setState(() => _activeOnly = v);
                  _loadMine();
                },
              ),
            ),
            const SizedBox(height: 8),
            ..._mineList(),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget? trailing) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
          ?trailing,
        ],
      );

  List<Widget> _packageList() {
    if (_packagesError != null) return [_ErrorText(_packagesError!)];
    final list = _packages;
    if (list == null) return const [_Muted(OwnerPromoStrings.loadingPackages)];
    if (list.isEmpty) return const [_Muted(OwnerPromoStrings.noPackages, icon: Icons.inventory_2_outlined)];
    return [
      for (final p in list)
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  OwnerBadge(OwnerPromoStrings.days(p.durationDays), tone: BadgeTone.blue),
                ],
              ),
              const SizedBox(height: 6),
              Text(p.description ?? OwnerPromoStrings.defaultDescription, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(Formatters.vnd(p.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ElevatedButton(
                    onPressed: () => _buy(p),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    child: const Text(OwnerPromoStrings.buy),
                  ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _mineList() {
    if (_mineError != null) return [_ErrorText(_mineError!)];
    final list = _mine;
    if (list == null) return const [_Muted(OwnerShopStrings.loading)];
    if (list.isEmpty) return const [_Muted(OwnerPromoStrings.noneBought, icon: Icons.campaign_outlined)];
    final now = DateTime.now();
    String d(DateTime? x) => x == null ? '—' : Formatters.date(x);
    return [
      for (final p in list)
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(p.packageName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  OwnerBadge(p.status.label, tone: _tone(p.status)),
                ],
              ),
              const SizedBox(height: 4),
              Text('${p.targetName ?? '—'} • ${OwnerPromoStrings.facility}'),
              Text(
                OwnerPromoStrings.period(d(p.startAt), d(p.endAt)) +
                    (p.daysLeft(now) > 0 ? ' • ${OwnerPromoStrings.daysLeft(p.daysLeft(now))}' : ''),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(Formatters.vnd(p.price), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
    ];
  }
}

class _PurchaseSheet extends StatefulWidget {
  final PromotionPackage pkg;
  final List<Facility> facilities;

  const _PurchaseSheet({required this.pkg, required this.facilities});

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  late String? _target = widget.facilities.firstOrNull?.id;
  int? _balance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppRepositories.ownerWallet.getBalance().then((v) {
      if (mounted) setState(() => _balance = v);
    }, onError: (_) {});
  }

  Future<void> _submit() async {
    final target = _target;
    if (target == null) {
      showOwnerSnack(context, OwnerPromoStrings.pickTarget, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppRepositories.owner.purchasePromotion(packageId: widget.pkg.id, facilityId: target);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showOwnerSnack(context, ownerErrorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.pkg;
    final enough = _balance == null || _balance! >= pkg.price;
    final hasTargets = widget.facilities.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(OwnerPromoStrings.buyTitle(pkg.name), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(OwnerPromoStrings.buySub(pkg.durationDays, Formatters.vnd(pkg.price)),
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              if (!hasTargets)
                _ToneText(OwnerPromoStrings.noTarget, tone: BadgeTone.blue)
              else
                DropdownButtonFormField<String>(
                  initialValue: _target,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: OwnerPromoStrings.targetLabel,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    for (final f in widget.facilities)
                      DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _target = v),
                ),
              const SizedBox(height: 10),
              const Text(OwnerPromoStrings.extendHint, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  const Text(OwnerPromoStrings.balance, style: TextStyle(color: AppColors.textSecondary)),
                  Text(_balance == null ? '…' : Formatters.vnd(_balance!), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (!enough) ...[
                const SizedBox(height: 10),
                _ToneText(OwnerPromoStrings.notEnough, tone: BadgeTone.red),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text(OwnerPromoStrings.cancel)),
                  ElevatedButton(
                    onPressed: _busy || !enough || !hasTargets ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
                    child: Text(OwnerPromoStrings.pay(Formatters.vnd(pkg.price))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );
}

class _Muted extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _Muted(this.text, {this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            if (icon != null) Icon(icon, size: 36, color: AppColors.textSecondary),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _ErrorText extends StatelessWidget {
  final String text;

  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) => _ToneText(text, tone: BadgeTone.red);
}

class _ToneText extends StatelessWidget {
  final String text;
  final BadgeTone tone;

  const _ToneText(this.text, {required this.tone});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: tone.foreground)),
      );
}
