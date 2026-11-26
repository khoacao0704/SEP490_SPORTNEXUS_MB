import 'package:flutter/material.dart';

/// Thẻ số liệu xếp 2 cột, cao theo nội dung (không cố định tỉ lệ nên chữ phóng to không bị tràn).
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const StatGrid({super.key, required this.children, this.spacing = 12});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [for (final c in children) SizedBox(width: width, child: c)],
          );
        },
      );
}
