import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/validators.dart';

/// Common form fields shared between post create and edit pages.
class PostFormFields extends StatelessWidget {
  final int category;
  final TextEditingController nameCtrl;
  final TextEditingController appearanceCtrl;
  final TextEditingController lostCityCtrl;
  final DateTime lostAt;
  final VoidCallback onSelectDate;
  final VoidCallback? onPickLocation;
  final double? selectedLatitude;
  final double? selectedLongitude;

  const PostFormFields({
    super.key,
    required this.category,
    required this.nameCtrl,
    required this.appearanceCtrl,
    required this.lostCityCtrl,
    required this.lostAt,
    required this.onSelectDate,
    this.onPickLocation,
    this.selectedLatitude,
    this.selectedLongitude,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = selectedLatitude != null && selectedLongitude != null;
    final l = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ========== Basic info ==========
        Text(l.get('basic_info'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        TextFormField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: l.get('title_label'),
            hintText: null,
          ),
          validator: (v) => Validators.required(v, l.get('title_label')),
        ),

        const SizedBox(height: 12),
        TextFormField(
          controller: appearanceCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: l.get('detail_desc_required'),
            hintText: category == 4
                ? l.get('desc_hint_item')
                : l.get('desc_hint_pet'),
            alignLabelWithHint: true,
          ),
          validator: (v) => Validators.minLength(v, 10, l.get('detail_desc_required')),
        ),

        const SizedBox(height: 20),

        // ========== Lost/missing info ==========
        Text(category == 4 ? l.get('lost_section_item') : l.get('lost_info'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(category == 4 ? l.get('lost_time_item') : l.get('lost_time')),
          subtitle: Text(
            '${lostAt.year}-${lostAt.month.toString().padLeft(2, '0')}-${lostAt.day.toString().padLeft(2, '0')} '
            '${lostAt.hour.toString().padLeft(2, '0')}:${lostAt.minute.toString().padLeft(2, '0')}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: onSelectDate,
        ),

        TextFormField(
          controller: lostCityCtrl,
          decoration: InputDecoration(
            labelText: l.get('location_required'),
            hintText: l.get('location_hint'),
          ),
          validator: (v) => Validators.required(v, l.get('location_required')),
        ),

        const SizedBox(height: 12),

        // ========== 定位选择 ==========
        if (onPickLocation != null)
          GestureDetector(
            onTap: onPickLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: hasLocation
                    ? AppTheme.successColor.withOpacity(0.08)
                    : AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasLocation
                      ? AppTheme.successColor.withOpacity(0.3)
                      : AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasLocation ? Icons.check_circle : Icons.my_location,
                    size: 20,
                    color: hasLocation ? AppTheme.successColor : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLocation ? l.get('location_selected') : l.get('add_location'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: hasLocation ? AppTheme.successColor : AppTheme.primaryColor,
                          ),
                        ),
                        if (hasLocation)
                          Text(
                            '${selectedLatitude!.toStringAsFixed(6)}, ${selectedLongitude!.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          )
                        else
                          Text(
                            l.get('location_map_hint'),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: hasLocation ? AppTheme.successColor : AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
