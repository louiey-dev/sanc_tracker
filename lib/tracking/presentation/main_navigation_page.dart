import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../history/presentation/history_screen.dart';
import '../../map/map_marker.dart';
import '../../map/presentation/markers_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/tracking_session.dart';
import 'track_map_screen.dart';
import 'tracking_controller.dart';

class MainNavigationPage extends ConsumerStatefulWidget {
  const MainNavigationPage({super.key});

  @override
  ConsumerState<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> {
  int _currentIndex = 0;
  final GlobalKey<TrackMapScreenState> _trackMapKey = GlobalKey();
  bool _isViewingSavedRoute = false;

  void _onTabSelected(int index) {
    if (index == 1) {
      ref.invalidate(sessionsListProvider);
    } else if (index == 2) {
      ref.invalidate(markersListProvider);
    }
    setState(() => _currentIndex = index);
  }

  void _handleSelectSession(TrackingSession session) {
    setState(() => _currentIndex = 0);
    _trackMapKey.currentState?.viewSessionRoute(session);
  }

  void _handleExitSavedRoute() {
    _trackMapKey.currentState?.exitSavedRoute();
  }

  void _handleFocusMarker(MapMarker marker) {
    setState(() => _currentIndex = 0);
    _trackMapKey.currentState?.focusMarker(marker);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TrackMapScreen(
            key: _trackMapKey,
            onSavedRouteStatusChanged: (viewing) {
              setState(() => _isViewingSavedRoute = viewing);
            },
          ),
          HistoryScreen(
            onSelectSession: _handleSelectSession,
            isViewingSavedRoute: _isViewingSavedRoute,
            onExitSavedRoute: _handleExitSavedRoute,
          ),
          MarkersScreen(
            onFocusMarker: _handleFocusMarker,
          ),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: [
          NavigationDestination(
            icon: _isViewingSavedRoute
                ? const Badge(
                    backgroundColor: AppColors.safetyAmber,
                    smallSize: 8,
                    child: Icon(Icons.explore_outlined),
                  )
                : const Icon(Icons.explore_outlined),
            selectedIcon: _isViewingSavedRoute
                ? const Badge(
                    backgroundColor: AppColors.safetyAmber,
                    smallSize: 8,
                    child: Icon(Icons.explore),
                  )
                : const Icon(Icons.explore),
            label: '추적',
          ),
          NavigationDestination(
            icon: _isViewingSavedRoute
                ? const Badge(
                    backgroundColor: AppColors.safetyAmber,
                    smallSize: 8,
                    child: Icon(Icons.route_outlined),
                  )
                : const Icon(Icons.route_outlined),
            selectedIcon: _isViewingSavedRoute
                ? const Badge(
                    backgroundColor: AppColors.safetyAmber,
                    smallSize: 8,
                    child: Icon(Icons.route),
                  )
                : const Icon(Icons.route),
            label: '기록',
          ),
          const NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: '마커',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
