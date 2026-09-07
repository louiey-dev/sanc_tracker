import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../map_marker.dart';
import '../../../media/media_item.dart';

class MarkerDetailSheet extends StatelessWidget {
  const MarkerDetailSheet({
    super.key,
    required this.marker,
    required this.mediaFuture,
    required this.onMove,
    required this.onEdit,
    required this.onDelete,
    required this.onCaptureMedia,
    required this.onPickGallery,
    required this.onOpenMedia,
    required this.onShowFullScreenPhoto,
    required this.onPlayVideo,
  });

  final MapMarker marker;
  final Future<List<MediaItem>> mediaFuture;
  final VoidCallback onMove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCaptureMedia;
  final VoidCallback onPickGallery;
  final void Function(MediaItem item) onOpenMedia;
  final void Function(String filePath) onShowFullScreenPhoto;
  final void Function(String filePath) onPlayVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          marker.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Text(
                            '${marker.latitude.toStringAsFixed(6)}, ${marker.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (marker.category != null && marker.category!.isNotEmpty)
                    Chip(
                      label: Text(marker.category!),
                      padding: EdgeInsets.zero,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      backgroundColor: AppColors.primaryContainer,
                      side: BorderSide.none,
                    ),
                ],
              ),
              if (marker.note != null && marker.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  marker.note!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Media section
              FutureBuilder<List<MediaItem>>(
                future: mediaFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final media = snapshot.data ?? const [];
                  if (media.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  if (media.length == 1) {
                    final item = media.single;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GestureDetector(
                        onTap: () => item.type == MediaType.photo
                            ? onShowFullScreenPhoto(item.filePath)
                            : onPlayVideo(item.filePath),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(
                              File(
                                item.type == MediaType.photo
                                    ? item.filePath
                                    : item.thumbnailPath,
                              ),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 180,
                                color: AppColors.backgroundLight,
                                child: const Center(
                                  child: Text('미디어 파일을 찾을 수 없습니다.'),
                                ),
                              ),
                            ),
                            if (item.type == MediaType.video)
                              Container(
                                decoration: const BoxDecoration(
                                  color: Color(0x66000000),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: media.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = media[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: GestureDetector(
                            onTap: () => onOpenMedia(item),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.file(
                                  File(
                                    item.type == MediaType.photo
                                        ? item.filePath
                                        : item.thumbnailPath,
                                  ),
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                                if (item.type == MediaType.video)
                                  const Icon(
                                    Icons.play_circle_fill,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Primary media actions (Capture / Gallery)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCaptureMedia,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('촬영'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('갤러리'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Marker management actions (Move, Edit, Delete)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: onMove,
                      icon: const Icon(Icons.open_with_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('위치 이동'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('수정'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        foregroundColor: AppColors.trackingStop,
                        side: const BorderSide(color: AppColors.trackingStop),
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('삭제'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
