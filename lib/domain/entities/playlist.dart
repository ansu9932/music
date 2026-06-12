import 'package:freezed_annotation/freezed_annotation.dart';

part 'playlist.freezed.dart';
part 'playlist.g.dart';

/// A user-created, locally-stored playlist (ordered list of track ids).
@freezed
class Playlist with _$Playlist {
  const factory Playlist({
    required String id,
    required String name,
    @Default(<String>[]) List<String> trackIds,
    @Default(0) int updatedAtMs,
  }) = _Playlist;

  const Playlist._();

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  int get length => trackIds.length;
  bool get isEmpty => trackIds.isEmpty;
}
