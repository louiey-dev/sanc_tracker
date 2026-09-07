import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/tracking_state.dart';
import 'tracking_stat_cell.dart';

/// Floating HUD card that displays live tracking metrics and action buttons.
///
/// Supports folding/collapsing to minimize screen footprint and maximize map visibility.
class TrackingHudCard extends StatefulWidget {
  const TrackingHudCard({
    super.key,
    required this.tracking,
    required this.onToggleTracking,
    this.initiallyCollapsed = true,
  });

  final TrackingState tracking;
  final VoidCallback onToggleTracking;
  final bool initiallyCollapsed;

  @override
  State<TrackingHudCard> createState() => _TrackingHudCardState();
}

class _TrackingHudCardState extends State<TrackingHudCard> {
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initiallyCollapsed;
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return hours > 0
        ? '${two(hours)}:${two(minutes)}:${two(secs)}'
        : '${two(minutes)}:${two(secs)}';
  }

  @override
  Widget build(BuildContext context) {
    final isTracking = widget.tracking.isTracking;
    final distanceKm =
        (widget.tracking.distanceMeters / 1000).toStringAsFixed(2);
    final speedKmh = widget.tracking.currentSpeedKmh.toStringAsFixed(1);
    final durationStr = _formatDuration(widget.tracking.duration);

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _isCollapsed ? 10 : 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Status & Collapse Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Status indicator & text (tap to toggle collapse)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isTracking
                                  ? AppColors.trackingLive
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isTracking ? '추적 중' : '추적 대기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isTracking
                                  ? AppColors.trackingLive
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isTracking
                                  ? '$durationStr • $distanceKm km'
                                  : '위치 ${widget.tracking.route.length}개',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Right: Controls (Compact button when collapsed + Arrow toggle)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCollapsed) ...[
                      SizedBox(
                        height: 36,
                        child: FilledButton.icon(
                          onPressed: widget.onToggleTracking,
                          style: FilledButton.styleFrom(
                            backgroundColor: isTracking
                                ? AppColors.trackingStop
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(
                            isTracking
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isTracking ? '추적 중지' : '시작',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: Icon(
                        _isCollapsed
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      tooltip: _isCollapsed ? '메뉴 펼치기' : '메뉴 접기',
                      onPressed: () =>
                          setState(() => _isCollapsed = !_isCollapsed),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),

            if (!_isCollapsed) ...[
              const SizedBox(height: 14),
              // Metrics 3 columns
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TrackingStatCell(
                    icon: Icons.timer_outlined,
                    label: '시간',
                    value: durationStr,
                    accentColor: isTracking ? AppColors.primaryDark : null,
                  ),
                  Container(width: 1, height: 32, color: AppColors.borderLight),
                  TrackingStatCell(
                    icon: Icons.straighten,
                    label: '거리',
                    value: distanceKm,
                    unit: 'km',
                  ),
                  Container(width: 1, height: 32, color: AppColors.borderLight),
                  TrackingStatCell(
                    icon: Icons.speed,
                    label: '속도',
                    value: speedKmh,
                    unit: 'km/h',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Action button (increased height to 52 & generous padding to avoid text clipping)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: widget.onToggleTracking,
                  style: FilledButton.styleFrom(
                    backgroundColor: isTracking
                        ? AppColors.trackingStop
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 24,
                  ),
                  label: Text(
                    isTracking ? '추적 중지' : '시작',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
