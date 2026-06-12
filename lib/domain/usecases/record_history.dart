import '../../core/errors/result.dart';
import '../entities/track.dart';
import '../repositories/user_repository.dart';

/// Appends [track] to local streaming history (de-duplicated, most-recent).
class RecordHistory {
  const RecordHistory(this._repo);
  final UserRepository _repo;

  Future<Result<void>> call(Track track) => _repo.recordHistory(track);
}
