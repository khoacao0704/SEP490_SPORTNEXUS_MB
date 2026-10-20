import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings/split_payment_strings.dart';
import '../../core/utils/validators.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/booking_repository.dart';
import '../../models/booking.dart';
import '../../theme/app_colors.dart';

/// Ô nhập SĐT + nút Thêm: tìm tài khoản rồi trả về qua [onFound]. [excludeIds] = đã mời (báo trùng).
class InviteByPhoneField extends StatefulWidget {
  final ValueChanged<PlayerLookup> onFound;
  final Set<String> excludeIds;

  const InviteByPhoneField({super.key, required this.onFound, this.excludeIds = const {}});

  @override
  State<InviteByPhoneField> createState() => _InviteByPhoneFieldState();
}

class _InviteByPhoneFieldState extends State<InviteByPhoneField> {
  final _controller = TextEditingController();
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final phone = _controller.text.trim();
    final invalid = Validators.phone(phone);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final player = await AppRepositories.booking.findPlayerByPhone(phone);
      if (!mounted) return;
      if (widget.excludeIds.contains(player.id)) {
        setState(() => _error = SplitPaymentStrings.alreadyInvited);
        return;
      }
      _controller.clear();
      widget.onFound(player);
    } on BookingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: SplitPaymentStrings.invitePhoneHint,
              errorText: _error,
              errorMaxLines: 2,
              isDense: true,
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _searching ? null : _add,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _searching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text(SplitPaymentStrings.inviteAdd),
          ),
        ),
      ],
    );
  }
}

/// Một người được mời: tên + SĐT đã che, có nút bỏ khi [onRemove] khác null.
class InviteeTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onRemove;

  const InviteeTile({super.key, required this.name, required this.subtitle, this.trailing, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.lightGreen,
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: const TextStyle(color: AppColors.darkGreen, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ??
          (onRemove == null ? null : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onRemove)),
    );
  }
}
