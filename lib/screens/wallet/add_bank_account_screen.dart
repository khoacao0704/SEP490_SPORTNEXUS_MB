import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/wallet_rules.dart';
import '../../core/strings/wallet_strings.dart';
import '../../core/utils/text_utils.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../theme/app_colors.dart';

/// Pop về [BankAccount] vừa lưu.
class AddBankAccountScreen extends StatefulWidget {
  /// Ví dùng cho màn này; bỏ trống = ví người chơi. Chủ sân truyền ví của Chủ sân.
  final WalletRepository? wallet;

  const AddBankAccountScreen({super.key, this.wallet});

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  WalletRepository get _wallet => widget.wallet ?? AppRepositories.wallet;

  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _holderController = TextEditingController();
  VietnamBank? _bank;
  bool _bankError = false;
  bool _isSaving = false;

  static final RegExp _accountNumberPattern = RegExp(r'^\d{6,19}$');
  static final RegExp _holderPattern = RegExp(r'^[A-Z ]+$');

  @override
  void dispose() {
    _accountNumberController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _bankError = _bank == null);
    if (!formOk || _bank == null) return;

    setState(() => _isSaving = true);
    try {
      final account = await _wallet.addBankAccount(
        bankCode: _bank!.code,
        bankName: _bank!.name,
        accountNumber: _accountNumberController.text.trim(),
        accountHolder: _holderController.text.trim(),
      );
      if (mounted) Navigator.pop(context, account);
    } on WalletException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _pickBank() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                WalletStrings.chooseBank,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
            ),
            ...VietnamBanks.all.map((bank) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lightGreen,
                    child: Text(
                      bank.code,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.darkGreen),
                    ),
                  ),
                  title: Text(bank.name),
                  trailing: bank.code == _bank?.code ? const Icon(Icons.check, color: AppColors.primaryGreen) : null,
                  onTap: () {
                    setState(() {
                      _bank = bank;
                      _bankError = false;
                    });
                    Navigator.pop(sheetContext);
                  },
                )),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 16),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          WalletStrings.addAccountTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _label(WalletStrings.bank),
            InkWell(
              onTap: _pickBank,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: _decoration(WalletStrings.chooseBank).copyWith(
                  errorText: _bankError ? WalletStrings.bankRequired : null,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down),
                ),
                isEmpty: _bank == null,
                child: _bank == null ? null : Text('${_bank!.name} (${_bank!.code})'),
              ),
            ),
            _label(WalletStrings.accountNumber),
            TextFormField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19)],
              decoration: _decoration(WalletStrings.accountNumberHint),
              validator: (v) =>
                  _accountNumberPattern.hasMatch(v?.trim() ?? '') ? null : WalletStrings.invalidAccountNumber,
            ),
            _label(WalletStrings.accountName),
            TextFormField(
              controller: _holderController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_HolderNameFormatter()],
              decoration: _decoration(WalletStrings.accountHolderHint).copyWith(
                helperText: WalletStrings.accountHolderNote,
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                return value.isNotEmpty && _holderPattern.hasMatch(value) ? null : WalletStrings.invalidAccountHolder;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.authPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white))
                    : const Text(WalletStrings.saveAccount, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tên chủ tài khoản: tự bỏ dấu và viết hoa ("Nguyễn Văn A" -> "NGUYEN VAN A"), bỏ ký tự lạ.
class _HolderNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = TextUtils.normalize(newValue.text).toUpperCase().replaceAll(RegExp(r'[^A-Z ]'), '');
    // normalize() cắt khoảng trắng 2 đầu; giữ lại khoảng trắng cuối để người dùng gõ được từ tiếp theo.
    final keepTrailingSpace = newValue.text.endsWith(' ') && text.isNotEmpty;
    final result = keepTrailingSpace ? '$text ' : text;
    return TextEditingValue(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}
