import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../tracking/data/tracking_preferences.dart';
import '../../tracking/presentation/tracking_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _saveTrackingPreferences(
    BuildContext context,
    WidgetRef ref,
    TrackingPreferences value,
  ) async {
    try {
      await ref.read(trackingPreferencesProvider.notifier).save(value);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('설정 저장 실패: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(trackingPreferencesProvider);
    final tracking = ref.watch(trackingControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: GPS & Tracking Configuration
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              '백그라운드 추적 설정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: AppColors.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.battery_saver_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    '배터리 절약 모드',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    '정확도를 낮춰 배터리 소모를 줄입니다. 변경은 추적 중지 상태에서 가능합니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: preferences.batterySaving,
                  onChanged: tracking.isTracking
                      ? null
                      : (value) => _saveTrackingPreferences(
                            context,
                            ref,
                            TrackingPreferences(
                              batterySaving: value,
                              intervalSeconds: preferences.intervalSeconds,
                            ),
                          ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(
                    Icons.timer_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Android GPS 요청 주기',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    '수신 주기는 OS 상태에 따라 달라질 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: DropdownButton<int>(
                    value: preferences.intervalSeconds,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10초')),
                      DropdownMenuItem(value: 30, child: Text('30초')),
                      DropdownMenuItem(value: 60, child: Text('60초')),
                    ],
                    onChanged: tracking.isTracking
                        ? null
                        : (value) {
                            if (value != null) {
                              _saveTrackingPreferences(
                                context,
                                ref,
                                TrackingPreferences(
                                  batterySaving: preferences.batterySaving,
                                  intervalSeconds: value,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: App Permissions
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              '권한 관리',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: AppColors.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.security_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                '앱 권한 설정 열기',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                '항상 허용 위치 권한, 알림, 카메라 권한을 확인하세요.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Geolocator.openAppSettings();
              },
            ),
          ),
          const SizedBox(height: 16),

          // Section: Guidance & Info
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              '백그라운드 안내 및 최적화',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Card(
            elevation: 0,
            color: AppColors.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: const Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '추적 중에는 화면이 꺼지거나 다른 앱을 사용 중이어도 위치가 기기에 안전하게 기록됩니다.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  ExpansionTile(
                    leading: Icon(
                      Icons.android_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      '기본 Android 권장 설정',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '위치 및 배터리 백그라운드 제한 해제',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          '1. 위치 권한: 설정 > 앱 > SANC Tracker > 권한 > 위치에서 [항상 허용] 선택\n'
                          '2. 배터리 사용량: 설정 > 앱 > SANC Tracker > 배터리에서 [제한 없음] 선택 (OS 강제 종료 방지)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 1, indent: 56),
                  ExpansionTile(
                    leading: Icon(
                      Icons.phone_android_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Samsung (Galaxy) 기기 설정',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '절전 예외 앱 등록',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          '설정 > 배터리 및 디바이스 케어 > 배터리 > 백그라운드 사용 제한 > [절전 예외 앱]에 SANC Tracker를 추가하세요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 1, indent: 56),
                  ExpansionTile(
                    leading: Icon(
                      Icons.mobile_friendly_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Xiaomi / Redmi 기기 설정',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '자동 시작 및 배터리 절약 해제',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          '설정 > 앱 관리 > SANC Tracker에서 [자동 시작] 활성화 후, 배터리 절약기 옵션을 [제한 없음]으로 변경하세요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 1, indent: 56),
                  ExpansionTile(
                    leading: Icon(
                      Icons.restore_page_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      '비정상 종료 자동 복구 안내',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '재부팅 및 강제 종료 복구',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text(
                          '기기가 재부팅되거나 OS에 의해 강제 종료되어도, 앱을 다시 실행하면 직전 추적 세션 및 사진 마커가 유실 없이 자동 복원됩니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'SANC Tracker v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
