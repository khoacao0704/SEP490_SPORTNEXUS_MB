import 'package:flutter/material.dart';

import '../../core/strings/community_strings.dart';
import '../../data/app_repositories.dart';
import '../../data/repositories/community_repository.dart';
import '../../models/sport.dart';
import '../../theme/app_colors.dart';
import '../../widgets/owner/photo_picker.dart';

/// Đăng bài mới (như ô đăng bài của Web): nội dung ≤ 5000 ký tự, môn (không bắt buộc), tối đa 10 ảnh.
/// Pop trả về bài vừa đăng.
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key});

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  final _content = TextEditingController();
  final List<String> _images = [];
  Sport? _sport;
  bool _uploading = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _content.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<void> _addImages() async {
    final room = CommunityRepository.maxImages - _images.length;
    if (room <= 0) return;
    final paths = (await pickPhotoPaths(context)).take(room).toList();
    if (paths.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final urls = await Future.wait(paths.map(AppRepositories.community.uploadImage));
      if (mounted) setState(() => _images.addAll(urls));
    } catch (e) {
      _error(e is CommunityException ? e.message : CommunityStrings.uploadError);
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _post() async {
    final text = _content.text.trim();
    if (text.isEmpty) return _error(CommunityStrings.contentRequired);
    setState(() => _posting = true);
    try {
      final created = await AppRepositories.community.createPost(content: text, mediaUrls: List.of(_images), sport: _sport);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(CommunityStrings.posted), backgroundColor: AppColors.primaryGreen));
      Navigator.pop(context, created);
      return;
    } catch (e) {
      _error(e is CommunityException ? e.message : CommunityStrings.postError);
    }
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textMain),
        title: const Text(CommunityStrings.composeTitle,
            style: TextStyle(color: AppColors.textMain, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _content,
            maxLines: 8,
            minLines: 4,
            maxLength: CommunityRepository.maxContent,
            decoration: InputDecoration(
              hintText: CommunityStrings.composeHint,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Sport?>(
            initialValue: _sport,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: CommunityStrings.sportOptional,
              isDense: true,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              const DropdownMenuItem<Sport?>(value: null, child: Text(CommunityStrings.noSport)),
              for (final s in Sport.values) DropdownMenuItem<Sport?>(value: s, child: Text(s.label)),
            ],
            onChanged: (v) => setState(() => _sport = v),
          ),
          const SizedBox(height: 14),
          Text(CommunityStrings.imagesLabel(_images.length, CommunityRepository.maxImages),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final url in _images)
                Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: OwnerImage(url, width: 72, height: 72)),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () => setState(() => _images.remove(url)),
                        child: Tooltip(
                          message: CommunityStrings.removeImage,
                          child: Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_images.length < CommunityRepository.maxImages)
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _addImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(_uploading ? CommunityStrings.uploading : CommunityStrings.addImage),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.divider))),
          child: ElevatedButton(
            onPressed: _posting || _uploading || _content.text.trim().isEmpty ? null : _post,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_posting ? CommunityStrings.posting : CommunityStrings.post,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
