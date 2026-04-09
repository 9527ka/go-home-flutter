import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Visibility/privacy selector used in create and edit forms.
class VisibilitySelector extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  const VisibilitySelector({
    super.key,
    required this.isPublic,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.textPrimary),
              const SizedBox(width: 6),
              const Text(
                '您是否同意以下信息被公开查看？',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isPublic ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isPublic ? AppTheme.primaryColor : Colors.grey[300]!,
                        width: isPublic ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPublic ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 18,
                          color: isPublic ? AppTheme.primaryColor : AppTheme.textHint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '同意',
                          style: TextStyle(
                            fontSize: 14,
                            color: isPublic ? AppTheme.primaryColor : AppTheme.textSecondary,
                            fontWeight: isPublic ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isPublic ? Colors.orange.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !isPublic ? Colors.orange : Colors.grey[300]!,
                        width: !isPublic ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          !isPublic ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 18,
                          color: !isPublic ? Colors.orange : AppTheme.textHint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '不同意',
                          style: TextStyle(
                            fontSize: 14,
                            color: !isPublic ? Colors.orange : AppTheme.textSecondary,
                            fontWeight: !isPublic ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPublic
                ? '信息审核通过后将公开展示，帮助更多人看到'
                : '内容仅自己可见，匹配成功后通知您',
            style: TextStyle(
              fontSize: 12,
              color: isPublic ? AppTheme.textSecondary : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}
