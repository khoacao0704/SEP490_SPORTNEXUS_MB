import 'package:flutter/material.dart';
import '../../core/strings/tournament_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../models/tournament.dart';
import '../../theme/app_colors.dart';
import '../../widgets/facility/sport_icon.dart';
import '../wallet/vietqr_payment_screen.dart';

enum _Method { wallet, vietQr }

/// Đăng ký giải: tên đội, thành viên (tra theo email/SĐT), đồng ý điều lệ, trả lệ phí.
/// Pop về [Tournament] đã cập nhật khi đăng ký thành công.
class TournamentRegisterScreen extends StatefulWidget {
  final Tournament tournament;

  const TournamentRegisterScreen({super.key, required this.tournament});

  @override
  State<TournamentRegisterScreen> createState() => _TournamentRegisterScreenState();
}

class _TournamentRegisterScreenState extends State<TournamentRegisterScreen> {
  final _teamName = TextEditingController();
  final _memberInput = TextEditingController();
  final List<TournamentMember> _teammates = [];
  TournamentMember? _me;
  int? _balance;
  _Method _method = _Method.wallet;
  bool _agreed = false;
  bool _isLookingUp = false;
  bool _isPaying = false;

  Tournament get _t => widget.tournament;
  bool get _isTeam => _t.entryType == TournamentEntryType.team;
  int get _memberCount => _teammates.length + 1;
  bool get _walletEnough => _balance != null && _balance! >= _t.entryFee;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadBalance();
  }

  @override
  void dispose() {
    _teamName.dispose();
    _memberInput.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AppRepositories.auth.getCurrentUser();
    if (user != null && mounted) setState(() => _me = TournamentMember(userId: user.id, name: user.fullName));
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await AppRepositories.paymentWallet.getBalance();
      if (mounted) setState(() => _balance = balance);
    } catch (_) {
      // Không có số dư thì vẫn cho chọn VietQR.
    }
  }

  Future<void> _addMember() async {
    final input = _memberInput.text.trim();
    if (input.isEmpty) return;
    if (_memberCount >= _t.maxMembers) {
      _showError(TournamentStrings.tooManyMembers);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLookingUp = true);
    try {
      final member = await AppRepositories.tournament.findPlayer(input);
      if (!mounted) return;
      if (member.userId == _me?.userId) {
        _showError(TournamentStrings.cannotAddSelf);
      } else if (_teammates.any((m) => m.userId == member.userId)) {
        _showError(TournamentStrings.duplicateMember);
      } else {
        setState(() => _teammates.add(member));
        _memberInput.clear();
      }
    } on TournamentException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(TournamentStrings.loadError);
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  String? _validate() {
    if (_isTeam && _teamName.text.trim().isEmpty) return TournamentStrings.teamNameRequired;
    if (_memberCount < _t.minMembers) {
      return _t.entryType == TournamentEntryType.pair
          ? TournamentStrings.needPartner
          : TournamentStrings.needMembers(_t.minMembers - _memberCount);
    }
    if (!_agreed) return TournamentStrings.mustAgree;
    if (_method == _Method.wallet && !_walletEnough) return TournamentStrings.insufficient;
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      _showError(error);
      return;
    }
    setState(() => _isPaying = true);
    try {
      if (_method == _Method.vietQr) {
        // Chuyển khoản đúng số lệ phí vào ví rồi trừ ví (BE xác nhận chuyển khoản).
        final order = await AppRepositories.paymentWallet.createTopUp(_t.entryFee);
        if (!mounted) return;
        final paid = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => VietQrPaymentScreen(order: order, wallet: AppRepositories.paymentWallet)),
        );
        if (paid != true) {
          if (mounted) setState(() => _isPaying = false);
          _loadBalance();
          return;
        }
      }
      final updated = await AppRepositories.tournament.register(TournamentRegistration(
        tournamentId: _t.id,
        teamName: _teamName.text,
        teammates: List.of(_teammates),
      ));
      if (mounted) Navigator.pop(context, updated);
    } on TournamentException catch (e) {
      _fail(e.message);
    } on WalletException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(TournamentStrings.loadError);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _isPaying = false);
    _loadBalance();
    _showError(message);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          TournamentStrings.registerTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.lightGreen,
                child: Icon(sportIcon(_t.sport), color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
                    Text(
                      '${_t.sport.label} • ${_t.entryType.label} • ${_t.facilityName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      TournamentStrings.dateRange(_t.startDate, _t.endDate),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.tagOrangeText),
                    ),
                  ],
                ),
              ),
            ],
          )),
          if (_isTeam) ...[
            _title(TournamentStrings.teamName),
            TextField(
              controller: _teamName,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: _inputDecoration(TournamentStrings.teamNameHint),
            ),
          ],
          _title(_t.maxMembers == 1
              ? TournamentStrings.playerInfo
              : _isTeam
                  ? TournamentStrings.membersTitle(_memberCount, _t.minMembers, _t.maxMembers)
                  : TournamentStrings.partnerTitle),
          _card(Column(
            children: [
              if (_me != null) _memberRow(_me!, isCaptain: true),
              for (final m in _teammates) _memberRow(m),
              if (_memberCount < _t.maxMembers) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _memberInput,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => _addMember(),
                        decoration: _inputDecoration(TournamentStrings.addMemberHint),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLookingUp ? null : _addMember,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLookingUp
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text(TournamentStrings.addMember),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(TournamentStrings.memberNote, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ],
          )),
          const SizedBox(height: 12),
          _card(Text(
            TournamentStrings.feeRules(_t.entryFee, _unitLower),
            style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.5),
          )),
          CheckboxListTile(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primaryGreen,
            title: const Text(TournamentStrings.agreeRules, style: TextStyle(fontSize: 13)),
          ),
          _title(TournamentStrings.paymentMethod),
          _methodTile(
            _Method.wallet,
            Icons.account_balance_wallet_outlined,
            TournamentStrings.payWallet,
            _balance == null ? '...' : TournamentStrings.balance(_balance!),
            warning: _balance != null && !_walletEnough,
          ),
          const SizedBox(height: 8),
          _methodTile(_Method.vietQr, Icons.qr_code_2, TournamentStrings.payVietQr, TournamentStrings.payVietQrHint),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      TournamentStrings.amountToPay,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Formatters.vnd(_t.entryFee),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isPaying ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isPaying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(TournamentStrings.confirmPay, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _unitLower => TournamentStrings.unit(_isTeam, _t.entryType == TournamentEntryType.pair).toLowerCase();

  Widget _memberRow(TournamentMember m, {bool isCaptain = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.lightGreen,
              child: Text(
                m.name.isEmpty ? '?' : m.name.characters.first,
                style: const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCaptain && _t.maxMembers > 1
                    ? '${m.name} ${TournamentStrings.you} – ${TournamentStrings.captain}'
                    : isCaptain
                        ? '${m.name} ${TournamentStrings.you}'
                        : m.name,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain),
              ),
            ),
            if (!isCaptain)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _isPaying ? null : () => setState(() => _teammates.remove(m)),
                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              ),
          ],
        ),
      );

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain)),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        counterText: '',
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      );

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );

  Widget _methodTile(_Method method, IconData icon, String title, String subtitle, {bool warning = false}) {
    final selected = _method == method;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isPaying ? null : () => setState(() => _method = method),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primaryGreen : AppColors.cardBorder, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: warning ? Colors.red : AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
