import 'package:isar/isar.dart';

part 'history_model.g.dart';

@collection
class HistoryModel {
  HistoryModel();

  Id id = Isar.autoIncrement;

  /// Unique per track so re-plays replace (de-dup) rather than duplicate.
  @Index(unique: true, replace: true)
  late String trackId;

  late String title;
  late String artist;
  String? artworkUrl;

  /// Epoch millis of the most recent play.
  @Index()
  late int playedAt;
}
