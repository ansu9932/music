import '../../core/errors/result.dart';
import '../entities/track.dart';
import '../repositories/user_repository.dart';

/// Toggles favorite state for [track], persisting locally.
class ToggleFavorite {
  const ToggleFavorite(this._repo);
  final UserRepository _repo;

  Future<Result<void>> call(Track track) => _repo.toggleFavorite(track);
}
