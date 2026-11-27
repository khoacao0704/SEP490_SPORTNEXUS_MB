import 'package:flutter/material.dart';

/// Hộp nhập một đoạn chữ (lý do hủy, lý do chuyển Admin…). Trả về chữ đã cắt khoảng trắng, `null` nếu bấm quay lại.
/// Ô nhập do hộp tự giữ và giải phóng khi hộp đóng hẳn (tránh dùng controller đã dispose trong lúc hộp đang đóng).
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirm,
  required String cancel,
  int maxLength = 500,
  bool destructive = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    hint: hint,
    confirm: confirm,
    cancel: cancel,
    maxLength: maxLength,
    destructive: destructive,
  ),
);

class _TextPromptDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String confirm;
  final String cancel;
  final int maxLength;
  final bool destructive;

  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.confirm,
    required this.cancel,
    required this.maxLength,
    required this.destructive,
  });

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      maxLength: widget.maxLength,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancel)),
      widget.destructive
          ? TextButton(
              onPressed: () => Navigator.pop(context, _controller.text.trim()),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(widget.confirm),
            )
          : ElevatedButton(
              onPressed: () => Navigator.pop(context, _controller.text.trim()),
              child: Text(widget.confirm),
            ),
    ],
  );
}
