import 'package:flutter/material.dart';

import '../../core/strings/ai_chat_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_repositories.dart';
import '../../models/ai_chat.dart';
import '../../theme/app_colors.dart';

/// Kết quả khi đóng màn lịch sử: cuộc trò chuyện muốn mở và các cuộc đã xoá.
typedef AiSessionsResult = ({String? open, Set<String> deleted});

/// Các cuộc trò chuyện cũ với AI: mở lại hoặc xoá.
class AiSessionsScreen extends StatefulWidget {
  const AiSessionsScreen({super.key});

  @override
  State<AiSessionsScreen> createState() => _AiSessionsScreenState();
}

class _AiSessionsScreenState extends State<AiSessionsScreen> {
  List<AiSession>? _sessions;
  String? _error;
  final Set<String> _deleted = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final sessions = await AppRepositories.aiChat.getSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
      if (mounted) setState(() => _error = AiChatStrings.loadError);
    }
  }

  Future<void> _delete(AiSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AiChatStrings.deleteTitle),
        content: const Text(AiChatStrings.deleteMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text(AiChatStrings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(AiChatStrings.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppRepositories.aiChat.deleteSession(s.id);
      if (!mounted) return;
      setState(() {
        _deleted.add(s.id);
        _sessions = _sessions?.where((e) => e.id != s.id).toList();
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(AiChatStrings.deleted)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(AiChatStrings.loadError)));
      }
    }
  }

  void _close({String? open}) => Navigator.pop<AiSessionsResult>(context, (open: open, deleted: _deleted));

  static String _when(DateTime? d) {
    if (d == null) return '';
    return Formatters.timeAgo(d, DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return PopScope<AiSessionsResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: AppColors.textMain),
          title: const Text(
            AiChatStrings.history,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
          ),
        ),
        body: _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                    TextButton(onPressed: _load, child: const Text(AiChatStrings.retry)),
                  ],
                ),
              )
            : sessions == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
            : sessions.isEmpty
            ? const Center(
                child: Text(AiChatStrings.noSessions, style: TextStyle(color: AppColors.textSecondary)),
              )
            : RefreshIndicator(
                color: AppColors.primaryGreen,
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    return Material(
                      color: AppColors.white,
                      child: ListTile(
                        onTap: () => _close(open: s.id),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.lightGreen,
                          child: Icon(Icons.smart_toy_outlined, color: AppColors.primaryGreen),
                        ),
                        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        // Tin cuối dài thì cắt, luôn chừa dòng thời gian.
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (s.lastMessage.isNotEmpty)
                              Text(s.lastMessage, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(
                              _when(s.lastMessageAt ?? s.createdAt),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: AiChatStrings.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(s),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
