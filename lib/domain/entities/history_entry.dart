import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_entry.freezed.dart';
part 'history_entry.g.dart';

/// A single streaming-history record, de-duplicated by [trackId] (most recent
/// play wins).
@freezed
class HistoryEntry with _$HistoryEntry {
  const factory HistoryEntry({
    required String trackId,
    required String title,
    required String artist,
    String? artworkUrl,
    required int playedAtMs,
  }) = _HistoryEntry;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$HistoryEntryFromJson(json);
}
