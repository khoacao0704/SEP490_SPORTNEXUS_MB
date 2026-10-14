import 'package:flutter/material.dart';
import '../../core/strings/split_payment_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/split_payment_repository.dart';
import '../../models/split_payment.dart';
import '../../theme/app_colors.dart';
import 'split_payment_screen.dart';

/// "Chia Tiền Sân": nhập mã từ link bạn bè gửi, và xem các lượt chia của mình.
class SplitPaymentsScreen extends StatefulWidget {
  const SplitPaymentsScreen({super.key});

  @override
  State<SplitPaymentsScreen> createState() => _SplitPaymentsScreenState();
}

class _SplitPaymentsScreenState extends State<SplitPaymentsScreen> {
  final _code = TextEditingController();
  List<SplitPayment> _items = [];
  bool _isLoading = true;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await AppRepositories.split.getMine();
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // Danh sách không tải được vẫn cho nhập mã.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openCode() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isOpening = true);
    try {
      final split = await AppRepositories.split.findByCode(code);
      if (!mounted) return;
      _code.clear();
      await _open(split);
    } on SplitPaymentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  Future<void> _open(SplitPayment split) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SplitPaymentScreen(splitId: split.id, initial: split)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(
          SplitPaymentStrings.listTitle,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              SplitPaymentStrings.enterCode,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _openCode(),
                    decoration: InputDecoration(
                      hintText: SplitPaymentStrings.codeHint,
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isOpening ? null : _openCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(SplitPaymentStrings.open),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              SplitPaymentStrings.mine,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textMain),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(SplitPaymentStrings.empty, style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              for (final s in _items)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  child: ListTile(
                    onTap: () => _open(s),
                    title: Text(s.facilityName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${s.schedule}\n${splitStatusLabel(s.status(now))}'),
                    isThreeLine: true,
                    trailing: Text(
                      SplitPaymentStrings.progress(s.paidCount, s.parts),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: splitStatusColors(s.status(now)).fg),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
