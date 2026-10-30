import 'package:flutter/material.dart';
import '../../core/strings/notification_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notification/notification_tile.dart';

/// Bật / tắt nhận thông báo theo nhóm. Nhóm bắt buộc luôn bật.
/// Mỗi lần gạt lưu ngay; lỗi thì trả công tắc về như cũ.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  /// Nhóm hiện trong cài đặt (app không có mục Cộng đồng). Cài đặt của nhóm ẩn vẫn được giữ nguyên khi lưu.
  static final List<NotificationGroup> shownGroups =
      NotificationGroup.values.where((g) => g != NotificationGroup.community).toList();

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  Set<NotificationGroup>? _disabled;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final disabled = await AppRepositories.notification.getDisabledGroups();
      if (mounted) setState(() => _disabled = disabled);
    } catch (_) {
      if (mounted) setState(() => _error = NotificationStrings.settingsLoadError);
    }
  }

  Future<void> _toggle(NotificationGroup group, bool enabled) async {
    final before = _disabled!;
    final after = {...before};
    enabled ? after.remove(group) : after.add(group);
    setState(() {
      _disabled = after;
      _saving = true;
    });
    try {
      await AppRepositories.notification.setDisabledGroups(after);
    } catch (e) {
      if (!mounted) return;
      setState(() => _disabled = before);
      final message = e is NotificationException ? e.message : NotificationStrings.settingsSaveError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          NotificationStrings.settings,
          style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text(NotificationStrings.retry)),
          ],
        ),
      );
    }
    final disabled = _disabled;
    if (disabled == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
    }
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            NotificationStrings.settingsIntro,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        Material(
          color: AppColors.white,
          child: Column(
            children: [
              for (final group in NotificationSettingsScreen.shownGroups)
                if (group.mandatory)
                  // Nhóm bắt buộc: ổ khoá thay công tắc (công tắc bị vô hiệu trông như đang tắt).
                  ListTile(
                    key: ValueKey('notification-setting-${group.apiValue}'),
                    leading: Icon(notificationIcon(group), color: notificationColors(group).fg),
                    title: Text(group.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${NotificationStrings.groupDescription(group)}\n${NotificationStrings.mandatoryNote}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                    ),
                  )
                else
                  SwitchListTile(
                    key: ValueKey('notification-setting-${group.apiValue}'),
                    secondary: Icon(notificationIcon(group), color: notificationColors(group).fg),
                    title: Text(group.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(NotificationStrings.groupDescription(group), style: const TextStyle(fontSize: 12)),
                    value: !disabled.contains(group),
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: _saving ? null : (on) => _toggle(group, on),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
