import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../media/media_item.dart';
import '../map_marker.dart';
import '../../tracking/presentation/tracking_controller.dart';

class MarkersScreen extends ConsumerStatefulWidget {
  const MarkersScreen({
    super.key,
    required this.onFocusMarker,
  });

  final ValueChanged<MapMarker> onFocusMarker;

  @override
  ConsumerState<MarkersScreen> createState() => _MarkersScreenState();
}

class _MarkersScreenState extends ConsumerState<MarkersScreen> {
  String _selectedCategory = '전체';
  final Map<String, Future<List<MediaItem>>> _mediaCache = {};

  void _refreshMarkers() {
    _mediaCache.clear();
    ref.invalidate(markersListProvider);
  }

  Future<void> _deleteMarker(MapMarker marker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마커 삭제'),
        content: Text('“${marker.title}” 마커를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(trackingRepositoryProvider).deleteMarker(marker.id);
      ref.invalidate(markersListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('“${marker.title}” 마커가 삭제되었습니다.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('마커 삭제 실패: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('마커'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMarkers,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(markersListProvider.future),
        child: ref.watch(markersListProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                Text('마커를 불러오지 못했습니다: $error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _refreshMarkers,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (allMarkers) {
            if (allMarkers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.place_outlined,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '저장된 마커가 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '지도 화면에서 길게 누르거나 사진을 촬영해 마커를 추가하세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            final categories = <String>{'전체'};
            for (final m in allMarkers) {
              if (m.category != null && m.category!.trim().isNotEmpty) {
                categories.add(m.category!.trim());
              }
            }

            final filteredMarkers = _selectedCategory == '전체'
                ? allMarkers
                : allMarkers
                    .where((m) => m.category?.trim() == _selectedCategory)
                    .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categories.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = cat == _selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = cat),
                              selectedColor: AppColors.primaryContainer,
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                Expanded(
                  child: filteredMarkers.isEmpty
                      ? Center(
                          child: Text(
                            '“$_selectedCategory” 분류의 마커가 없습니다.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: filteredMarkers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final marker = filteredMarkers[index];
                            final isPhoto = marker.category == '사진';
                            final isVideo = marker.category == '동영상';
                            return Card(
                              elevation: 0,
                              color: AppColors.surfaceLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                  color: AppColors.borderLight,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => widget.onFocusMarker(marker),
                                onLongPress: () => _deleteMarker(marker),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _buildMarkerLeading(
                                        marker,
                                        isPhoto,
                                        isVideo,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    marker.title,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (marker.category != null &&
                                                    marker.category!.isNotEmpty)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .backgroundLight,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color: AppColors
                                                            .borderLight,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      marker.category!,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${marker.latitude.toStringAsFixed(6)}, ${marker.longitude.toStringAsFixed(6)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            if (marker.note != null &&
                                                marker.note!.trim().isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                marker.note!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '마커 삭제',
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.textMuted,
                                          size: 20,
                                        ),
                                        onPressed: () => _deleteMarker(marker),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMarkerLeading(MapMarker marker, bool isPhoto, bool isVideo) {
    if (!isPhoto && !isVideo) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.place_rounded,
          color: AppColors.primary,
          size: 24,
        ),
      );
    }

    return FutureBuilder<List<MediaItem>>(
      future: _mediaCache.putIfAbsent(
        marker.id,
        () => ref.read(trackingRepositoryProvider).loadMedia(marker.id),
      ),
      builder: (context, snapshot) {
        final mediaList = snapshot.data ?? const [];
        final media = mediaList.isNotEmpty ? mediaList.last : null;
        final thumbPath = media?.thumbnailPath ?? media?.filePath;

        if (thumbPath != null && File(thumbPath).existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(thumbPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _fallbackMediaIcon(isPhoto, isVideo),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPhoto ? Icons.photo_camera : Icons.play_arrow,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return _fallbackMediaIcon(isPhoto, isVideo);
      },
    );
  }

  Widget _fallbackMediaIcon(bool isPhoto, bool isVideo) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.safetyAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isPhoto
            ? Icons.photo_camera_rounded
            : isVideo
                ? Icons.videocam_rounded
                : Icons.place_rounded,
        color: AppColors.safetyAmber,
        size: 24,
      ),
    );
  }
}
