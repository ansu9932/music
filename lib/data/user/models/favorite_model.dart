import 'package:isar/isar.dart';

part 'favorite_model.g.dart';

@collection
class FavoriteModel {
  FavoriteModel();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String trackId;

  late String title;
  late String artist;
  String? album;
  String? artworkUrl;
  String? directAudioUrl;
  int durationMs = 0;

  /// Epoch millis when favorited (for most-recent-first ordering).
  late int savedAt;
}
