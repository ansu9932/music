import 'package:isar/isar.dart';

part 'playlist_model.g.dart';

@collection
class PlaylistModel {
  PlaylistModel();

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String playlistId;

  @Index()
  late String name;

  List<String> trackIds = <String>[];

  late int createdAt;
  late int updatedAt;
}
