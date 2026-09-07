import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class TrackingPreferences {
  const TrackingPreferences({
    this.batterySaving = false,
    this.intervalSeconds = 10,
  });
  final bool batterySaving;
  final int intervalSeconds;
}

final trackingPreferencesProvider =
    NotifierProvider<TrackingPreferencesController, TrackingPreferences>(
      TrackingPreferencesController.new,
    );

class TrackingPreferencesController extends Notifier<TrackingPreferences> {
  @override
  TrackingPreferences build() => const TrackingPreferences();

  Future<File> get _file async => File(
    '${(await getApplicationDocumentsDirectory()).path}/tracking-preferences.json',
  );

  Future<void> load() async {
    final file = await _file;
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final seconds = json['intervalSeconds'];
    state = TrackingPreferences(
      batterySaving: json['batterySaving'] == true,
      intervalSeconds: [10, 30, 60].contains(seconds) ? seconds as int : 10,
    );
  }

  Future<void> save(TrackingPreferences value) async {
    await (await _file).writeAsString(
      jsonEncode({
        'batterySaving': value.batterySaving,
        'intervalSeconds': value.intervalSeconds,
      }),
      flush: true,
    );
    state = value;
  }
}
