import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Floating chip on the map that expands to show a legend of map markers and route line styles.
class MapLegendChip extends StatefulWidget {
  const MapLegendChip({super.key});

  @override
  State<MapLegendChip> createState() => _MapLegendChipState();
}

class _MapLegendChipState extends State<MapLegendChip> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      return Material(
        color: AppColors.surfaceLight,
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _isExpanded = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 4),
                Text(
                  '범례',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.surfaceLight,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.layers_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '지도 범례',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                InkResponse(
                  radius: 14,
                  onTap: () => setState(() => _isExpanded = false),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _buildLegendRow(
              icon: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              label: '현재 위치',
            ),
            const SizedBox(height: 6),
            _buildLegendRow(
              icon: Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.trackingLive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              label: '실시간 추적 경로',
            ),
            const SizedBox(height: 6),
            _buildLegendRow(
              icon: Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              label: '저장된 경로',
            ),
            const SizedBox(height: 6),
            _buildLegendRow(
              icon: Image.asset(
                'assets/icon/sanc_tracker_icon.png',
                width: 14,
                height: 14,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.place_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ),
              label: '장소 마커',
            ),
            const SizedBox(height: 6),
            _buildLegendRow(
              icon: Image.asset(
                'assets/icon/sanc_photo_marker.png',
                width: 14,
                height: 14,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.photo_camera_rounded,
                  size: 14,
                  color: AppColors.safetyAmber,
                ),
              ),
              label: '사진 마커',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow({required Widget icon, required String label}) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Center(child: icon),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
