import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config_repository.dart';

/// Conteúdo atual de `teams.json` (string pretty-printed) vindo do backend.
final configProvider = FutureProvider.autoDispose<String>((ref) async {
  return ConfigRepository.getConfig();
});
