import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/url_helper.dart';
import 'avatar_widget.dart';

/// 微信风格群组九宫格头像
/// 根据成员数量自动调整布局：1=全尺寸, 2=左右, 3=三角, 4=2x2, 5-9=多行网格
class GroupGridAvatar extends StatelessWidget {
  final List<String> avatars; // 成员头像路径列表
  final List<String> names; // 成员名称列表（用于字母占位）
  final double size;
  final double? borderRadius;

  const GroupGridAvatar({
    super.key,
    required this.avatars,
    required this.names,
    this.size = 48,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;
    final count = avatars.length.clamp(0, 9);

    if (count == 0) {
      return _placeholder(radius);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildGrid(count),
    );
  }

  Widget _buildGrid(int count) {
    final gap = size * 0.04;
    final padding = size * 0.06;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;

          if (count == 1) {
            return _cell(0, available);
          }

          if (count == 2) {
            final cellSize = (available - gap) / 2;
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cell(0, cellSize),
                  SizedBox(width: gap),
                  _cell(1, cellSize),
                ],
              ),
            );
          }

          if (count == 3) {
            final cellSize = (available - gap) / 2;
            return Column(
              children: [
                Center(child: _cell(0, cellSize)),
                SizedBox(height: gap),
                Row(
                  children: [
                    _cell(1, cellSize),
                    SizedBox(width: gap),
                    _cell(2, cellSize),
                  ],
                ),
              ],
            );
          }

          if (count == 4) {
            final cellSize = (available - gap) / 2;
            return Column(
              children: [
                Row(children: [
                  _cell(0, cellSize),
                  SizedBox(width: gap),
                  _cell(1, cellSize),
                ]),
                SizedBox(height: gap),
                Row(children: [
                  _cell(2, cellSize),
                  SizedBox(width: gap),
                  _cell(3, cellSize),
                ]),
              ],
            );
          }

          // 5-9: 3 columns, partial top row centered
          const cols = 3;
          final cellSize = (available - gap * (cols - 1)) / cols;
          final rows = <Widget>[];
          final topRowCount = count % cols;
          int idx = 0;

          if (topRowCount > 0 && topRowCount < cols) {
            // Center the partial top row
            final topRow = <Widget>[];
            for (int i = 0; i < topRowCount; i++) {
              if (i > 0) topRow.add(SizedBox(width: gap));
              topRow.add(_cell(idx++, cellSize));
            }
            rows.add(Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: topRow,
            ));
            rows.add(SizedBox(height: gap));
          }

          // Full rows
          while (idx < count) {
            final row = <Widget>[];
            for (int i = 0; i < cols && idx < count; i++) {
              if (i > 0) row.add(SizedBox(width: gap));
              row.add(_cell(idx++, cellSize));
            }
            rows.add(Row(children: row));
            if (idx < count) rows.add(SizedBox(height: gap));
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rows,
          );
        },
      ),
    );
  }

  Widget _cell(int index, double cellSize) {
    final path = index < avatars.length ? avatars[index] : '';
    final name = index < names.length ? names[index] : '';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    // System avatar
    final systemKey = AvatarWidget.extractSystemAvatarKey(path);
    if (systemKey != null) {
      final style = AvatarWidget.systemAvatarStyles[systemKey];
      final color = (style != null ? style[0] : AppTheme.primaryColor) as Color;
      final icon = (style != null ? style[1] : Icons.person) as IconData;
      return SizedBox(
        width: cellSize,
        height: cellSize,
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(cellSize * 0.2),
          ),
          child: Center(
            child: Icon(icon, size: cellSize * 0.6, color: color),
          ),
        ),
      );
    }

    // Network image
    if (path.isNotEmpty) {
      final absUrl = UrlHelper.ensureAbsolute(path);
      if (UrlHelper.isValidNetworkUrl(absUrl)) {
        return SizedBox(
          width: cellSize,
          height: cellSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cellSize * 0.2),
            child: CachedNetworkImage(
              imageUrl: absUrl,
              width: cellSize,
              height: cellSize,
              fit: BoxFit.cover,
              placeholder: (_, __) => _letterCell(initial, cellSize),
              errorWidget: (_, __, ___) => _letterCell(initial, cellSize),
            ),
          ),
        );
      }
    }

    return _letterCell(initial, cellSize);
  }

  Widget _letterCell(String initial, double cellSize) {
    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(cellSize * 0.2),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: cellSize * 0.42,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.group, size: size * 0.5, color: AppTheme.textHint),
    );
  }
}
