import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../tracking/domain/location_point.dart';
import '../../tracking/domain/tracking_session.dart';
import '../../tracking/presentation/tracking_controller.dart';
import '../../export_import/application/export_import_service.dart';
import 'widgets/session_card.dart';
import 'widgets/session_title_dialog.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({
    super.key,
    required this.onSelectSession,
    required this.isViewingSavedRoute,
    required this.onExitSavedRoute,
  });

  final ValueChanged<TrackingSession> onSelectSession;
  final bool isViewingSavedRoute;
  final VoidCallback onExitSavedRoute;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _selectedSessionIds = {};
  bool _isSelectingSessions = false;
  bool _isDeletingSessions = false;
  final Map<String, Future<SessionSummaryData>> _summaryDataCache = {};

  void _refreshSessions() {
    _summaryDataCache.clear();
    ref.invalidate(sessionsListProvider);
  }

  Future<SessionSummaryData> _sessionSummaryData(TrackingSession session) {
    return _summaryDataCache.putIfAbsent(session.id, () async {
      final points = await ref
          .read(trackingRepositoryProvider)
          .loadPoints(session.id);
      final sorted = [...points]
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      final start =
          sorted.isEmpty ? session.startedAt : sorted.first.recordedAt;
      final end =
          session.endedAt ??
          (sorted.isEmpty ? session.updatedAt : sorted.last.recordedAt);
      final distance = _calculateDistance(sorted);
      return SessionSummaryData(
        duration: end.difference(start),
        distanceKm: distance,
        pointCount: sorted.length,
        start: start,
        end: end,
        status: session.status,
      );
    });
  }

  double _calculateDistance(List<LocationPoint> points) {
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return meters / 1000;
  }

  void _toggleSessionSelection(String id) {
    setState(() {
      _isSelectingSessions = true;
      if (!_selectedSessionIds.add(id)) {
        _selectedSessionIds.remove(id);
      }
      if (_selectedSessionIds.isEmpty) {
        _isSelectingSessions = false;
      }
    });
  }

  Future<void> _deleteSelectedSessions() async {
    final ids = _selectedSessionIds.toList();
    if (ids.isEmpty || _isDeletingSessions) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('세션 삭제'),
        content: Text('선택한 ${ids.length}개 세션과 저장된 위치 데이터를 삭제하시겠습니까?'),
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

    setState(() => _isDeletingSessions = true);
    try {
      final repository = ref.read(trackingRepositoryProvider);
      for (final id in ids) {
        await repository.deleteSession(id);
        _selectedSessionIds.remove(id);
      }
      if (mounted) {
        setState(() => _isSelectingSessions = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ids.length}개 세션이 삭제되었습니다.')),
        );
        _refreshSessions();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('세션 삭제 오류: $error')));
      }
    } finally {
      if (mounted) setState(() => _isDeletingSessions = false);
    }
  }

  Future<void> _editSessionTitle(TrackingSession session) async {
    final newTitle = await SessionTitleDialog.show(
      context,
      initialTitle: session.title ?? '',
    );
    if (newTitle == null || !mounted) return;

    final trimmed = newTitle.trim();
    if (trimmed == (session.title ?? '')) return;

    final updated = session.copyWith(
      title: trimmed.isEmpty ? null : trimmed,
      clearTitle: trimmed.isEmpty,
      updatedAt: DateTime.now().toUtc(),
    );
    try {
      await ref.read(trackingRepositoryProvider).updateSession(updated);
      _refreshSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trimmed.isEmpty ? '기록 이름이 초기화되었습니다.' : '기록 이름이 수정되었습니다.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기록 이름 수정 실패: $error')),
        );
      }
    }
  }

  Future<void> _confirmLoadSession(TrackingSession session) async {
    final displayName =
        session.title != null && session.title!.trim().isNotEmpty
            ? '“${session.title}”'
            : '이 세션';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('경로 보기'),
        content: Text('$displayName의 이동 경로를 지도에 표시하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.onSelectSession(session);
    }
  }

  Future<void> _exportSession(TrackingSession session) async {
    final action = await showModalBottomSheet<ExportAction>(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.drive_file_move_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '기록 내보내기',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.title ?? '기록 데이터',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Section 1: Save directly to phone
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '내 폰 저장소에 파일로 저장',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.download_rounded, color: AppColors.primary),
                title: const Text('GPX로 폰에 저장 (.gpx)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('다운로드 폴더 등을 선택하여 파일로 직접 저장', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, ExportAction.saveToDeviceGpx),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.download_rounded, color: AppColors.primary),
                title: const Text('GeoJSON으로 폰에 저장 (.geojson)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('표준 지리 정보 포맷으로 폰에 직접 저장', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, ExportAction.saveToDeviceGeoJson),
              ),
              const Divider(height: 20),
              // Section 2: Share via OS Sheet
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '다른 앱이나 기기로 공유',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
                title: const Text('GPX 파일 공유', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('카카오톡, Quick Share(PC 전송), 메일 등으로 전송', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, ExportAction.shareGpx),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
                title: const Text('GeoJSON 파일 공유', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('카카오톡, Quick Share, 클라우드 등으로 전송', style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(context, ExportAction.shareGeoJson),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == null || !mounted) return;

    try {
      final service = ref.read(exportImportServiceProvider);
      switch (action) {
        case ExportAction.saveToDeviceGpx:
          final path = await service.saveSessionToDevice(
            session: session,
            format: UniversalExportFormat.gpx,
          );
          if (path != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('GPX 파일이 폰에 저장되었습니다.')),
            );
          }
          break;
        case ExportAction.saveToDeviceGeoJson:
          final path = await service.saveSessionToDevice(
            session: session,
            format: UniversalExportFormat.geojson,
          );
          if (path != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('GeoJSON 파일이 폰에 저장되었습니다.')),
            );
          }
          break;
        case ExportAction.shareGpx:
          final file = await service.exportSessionToFile(
            session: session,
            format: UniversalExportFormat.gpx,
          );
          await service.shareFile(
            file,
            subject: '${session.title ?? 'SANC Tracker 경로'} (GPX)',
          );
          break;
        case ExportAction.shareGeoJson:
          final file = await service.exportSessionToFile(
            session: session,
            format: UniversalExportFormat.geojson,
          );
          await service.shareFile(
            file,
            subject: '${session.title ?? 'SANC Tracker 경로'} (GeoJSON)',
          );
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }

  Future<void> _importFile() async {
    try {
      final service = ref.read(exportImportServiceProvider);
      final picked = await service.pickAndReadImportFile();
      if (picked == null || !mounted) return;

      final bundle = service.parseContent(picked.content);
      if (bundle.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일에서 가져올 수 있는 세션이나 마커를 찾지 못했습니다.')),
          );
        }
        return;
      }

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('기록 가져오기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('파일: ${picked.fileName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('• 세션: ${bundle.totalSessionsCount}개'),
              Text('• 경로 지점: ${bundle.totalPointsCount}개'),
              Text('• 장소 마커: ${bundle.totalMarkersCount}개'),
              const SizedBox(height: 16),
              const Text(
                '기존 기록을 유지하면서 이 데이터를 안전하게 추가합니다. 계속하시겠습니까?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('가져오기'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      await service.commitImport(bundle);
      _refreshSessions();
      ref.invalidate(markersListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${bundle.totalSessionsCount}개 세션(${bundle.totalPointsCount}개 지점)과 ${bundle.totalMarkersCount}개 마커를 가져왔습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가져오기 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          _isSelectingSessions ? '${_selectedSessionIds.length}개 선택됨' : '기록',
        ),
        actions: [
          if (_isSelectingSessions) ...[
            TextButton(
              onPressed: _isDeletingSessions
                  ? null
                  : () => setState(() {
                        _isSelectingSessions = false;
                        _selectedSessionIds.clear();
                      }),
              child: const Text('취소'),
            ),
            IconButton(
              tooltip: '선택한 세션 삭제',
              onPressed: _isDeletingSessions || _selectedSessionIds.isEmpty
                  ? null
                  : _deleteSelectedSessions,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
          ] else ...[
            if (widget.isViewingSavedRoute)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: const Text('경로 보기 종료'),
                  backgroundColor: AppColors.safetyAmber.withValues(alpha: 0.2),
                  onPressed: widget.onExitSavedRoute,
                ),
              ),
            IconButton(
              tooltip: '기록 가져오기 (GPX / GeoJSON)',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: _importFile,
            ),
            IconButton(
              tooltip: '새로고침',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshSessions,
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(sessionsListProvider.future),
        child: ref.watch(sessionsListProvider).when(
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
                Text('기록을 불러오지 못했습니다: $error'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _refreshSessions,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
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
                        Icons.route_outlined,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '저장된 이동 기록이 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '추적을 시작하고 이동을 완료하면 이곳에 표시됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isSelected = _selectedSessionIds.contains(session.id);
                return SessionCard(
                  session: session,
                  summaryDataFuture: _sessionSummaryData(session),
                  isSelected: isSelected,
                  isSelecting: _isSelectingSessions,
                  onTap: () {
                    if (_isSelectingSessions) {
                      _toggleSessionSelection(session.id);
                    } else {
                      _confirmLoadSession(session);
                    }
                  },
                  onLongPress: () => _toggleSessionSelection(session.id),
                  onSelectChanged: (_) => _toggleSessionSelection(session.id),
                  onEditTitle: () => _editSessionTitle(session),
                  onExport: () => _exportSession(session),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
