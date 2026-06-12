import '../repositories/session_repository.dart';

/// Restores the last-session snapshot (active track, queue, position, modes).
class RestoreSession {
  const RestoreSession(this._repo);
  final SessionRepository _repo;

  Future<SessionSnapshot?> call() => _repo.restore();
}
