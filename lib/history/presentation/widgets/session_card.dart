import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../tracking/domain/tracking_session.dart';

class SessionSummaryData {
  const SessionSummaryData({
    required this.duration,
    required this.distanceKm,
    required this.pointCount,
    required this.start,
    required this.end,
    required this.status,
  });

  final Duration duration;
  final double distanceKm;
  final int pointCount;
  final DateTime start;
  final DateTime end;
  final TrackingSessionStatus status;
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    this.summaryFuture,
    this.summaryDataFuture,
    required this.isSelected,
    required this.isSelecting,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectChanged,
    this.onEditTitle,
  });

  final TrackingSession session;
  final Future<String>? summaryFuture;
  final Future<SessionSummaryData>? summaryDataFuture;
  final bool isSelected;
  final bool isSelecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool?> onSelectChanged;
  final VoidCallback? onEditTitle;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return hours > 0 ? '$hours시간 $minutes분' : '$minutes분 $secs초';
  }

  Widget _metricChip({
    required IconData icon,
    required String value,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isPrimary ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
              color: isPrimary ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(SessionSummaryData data) {
    final isCompleted = data.status == TrackingSessionStatus.completed;
    final durationStr = _formatDuration(data.duration);
    final distanceStr = '${data.distanceKm.toStringAsFixed(2)} km';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primaryContainer
                    : AppColors.trackingLive.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_outline_rounded
                        : Icons.fiber_manual_record_rounded,
                    size: 11,
                    color: isCompleted
                        ? AppColors.primary
                        : AppColors.trackingLive,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isCompleted ? '완료' : '기록 중',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? AppColors.primary
                          : AppColors.trackingLive,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_formatTime(data.start)} ~ ${_formatTime(data.end)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _metricChip(
              icon: Icons.straighten_rounded,
              value: distanceStr,
              isPrimary: true,
            ),
            _metricChip(
              icon: Icons.timer_outlined,
              value: durationStr,
            ),
            _metricChip(
              icon: Icons.pin_drop_outlined,
              value: '${data.pointCount}개 지점',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomTitle =
        session.title != null && session.title!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      color: isSelected
          ? AppColors.primaryContainer.withValues(alpha: 0.5)
          : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isSelecting) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primary,
                  onChanged: onSelectChanged,
                ),
                const SizedBox(width: 8),
              ] else ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCustomTitle
                          ? session.title!
                          : _formatDate(session.startedAt),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasCustomTitle) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(session.startedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (summaryDataFuture != null)
                      FutureBuilder<SessionSummaryData>(
                        future: summaryDataFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return _buildMetrics(snapshot.data!);
                          }
                          return const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '상세 정보 계산 중...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      )
                    else if (summaryFuture != null)
                      FutureBuilder<String>(
                        future: summaryFuture,
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? '상세 정보 계산 중...',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              if (!isSelecting) ...[
                if (onEditTitle != null)
                  IconButton(
                    tooltip: '이름 수정',
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: onEditTitle,
                  ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
