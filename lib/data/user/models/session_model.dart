import 'package:isar/isar.dart';

part 'session_model.g.dart';

/// Single-row last-session playback context (id is always 0).
@collection
class SessionModel {
  SessionModel();

  Id id = 0;

  String? activeTrackId;
  List<String> queueTrackIds = <String>[];
  int positionMs = 0;

  /// 0 = off, 1 = one, 2 = all.
  int repeatMode = 0;
  bool shuffle = false;
}
