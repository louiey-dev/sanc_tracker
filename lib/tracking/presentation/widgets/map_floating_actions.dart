import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class MapFloatingActions extends StatelessWidget {
  const MapFloatingActions({
    super.key,
    required this.onMoveToCurrentLocation,
    required this.onCaptureCurrentLocation,
    this.isViewingSavedRoute = false,
    this.onExitSavedRoute,
  });

  final VoidCallback onMoveToCurrentLocation;
  final VoidCallback onCaptureCurrentLocation;
  final bool isViewingSavedRoute;
  final VoidCallback? onExitSavedRoute;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isViewingSavedRoute && onExitSavedRoute != null) ...[
          FloatingActionButton.small(
            heroTag: 'exit-saved-route',
            tooltip: '저장 경로 보기 종료',
            backgroundColor: AppColors.surfaceLight,
            foregroundColor: AppColors.trackingStop,
            onPressed: onExitSavedRoute,
            child: const Icon(Icons.close_rounded),
          ),
          const SizedBox(height: 10),
        ],
        FloatingActionButton.small(
          heroTag: 'capture-current-location',
          tooltip: '현재 위치에서 사진 촬영',
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.primary,
          onPressed: onCaptureCurrentLocation,
          child: const Icon(Icons.camera_alt_rounded),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.small(
          heroTag: 'move-to-current-location',
          tooltip: '현재 위치로 이동',
          backgroundColor: AppColors.surfaceLight,
          foregroundColor: AppColors.primary,
          onPressed: onMoveToCurrentLocation,
          child: const Icon(Icons.my_location_rounded),
        ),
      ],
    );
  }
}
