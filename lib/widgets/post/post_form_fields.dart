import 'package:flutter/material.dart';
import '../../utils/validators.dart';

/// Common form fields shared between post create and edit pages.
class PostFormFields extends StatelessWidget {
  final int category;
  final TextEditingController nameCtrl;
  final TextEditingController speciesCtrl;
  final TextEditingController appearanceCtrl;
  final TextEditingController lostCityCtrl;
  final DateTime lostAt;
  final VoidCallback onSelectDate;

  const PostFormFields({
    super.key,
    required this.category,
    required this.nameCtrl,
    required this.speciesCtrl,
    required this.appearanceCtrl,
    required this.lostCityCtrl,
    required this.lostAt,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ========== Basic info ==========
        const Text('基本信息', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        TextFormField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: '标题',
            hintText: null,
          ),
          validator: (v) => Validators.required(v, '标题'),
        ),

        if (category == 1) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: speciesCtrl,
            decoration: const InputDecoration(labelText: '品种'),
          ),
        ],

        if (category == 4) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: speciesCtrl,
            decoration: const InputDecoration(labelText: '物品类型', hintText: '如：钱包、手机、钥匙等'),
          ),
        ],

        const SizedBox(height: 12),
        TextFormField(
          controller: appearanceCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: '详细描述 *',
            hintText: category == 1
                ? '体貌特征、走失经过等详细信息（至少10个字）'
                : category == 4
                    ? '外观特征、丢失经过等详细信息（至少10个字）'
                    : '体貌特征、走失经过等详细信息（至少10个字）',
            alignLabelWithHint: true,
          ),
          validator: (v) => Validators.minLength(v, 10, '详细描述'),
        ),

        const SizedBox(height: 20),

        // ========== Lost/missing info ==========
        Text(category == 4 ? '丢失信息' : '走失信息', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(category == 4 ? '丢失时间' : '走失时间'),
          subtitle: Text(
            '${lostAt.year}-${lostAt.month.toString().padLeft(2, '0')}-${lostAt.day.toString().padLeft(2, '0')} '
            '${lostAt.hour.toString().padLeft(2, '0')}:${lostAt.minute.toString().padLeft(2, '0')}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: onSelectDate,
        ),

        TextFormField(
          controller: lostCityCtrl,
          decoration: const InputDecoration(
            labelText: '地点 *',
            hintText: '如：北京市朝阳区XX路',
          ),
          validator: (v) => Validators.required(v, '地点'),
        ),
      ],
    );
  }
}
