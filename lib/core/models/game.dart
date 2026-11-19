enum GameListType { library, wishlist }

enum GameStatus { playing, completed, dropped }

enum GameSource { manual, steam, epic, rawg }

enum GameSortMode {
  ratingAscending,
  ratingDescending,
  nameAscending,
  nameDescending,
  playtimeAscending,
  playtimeDescending,
  manual,
}

extension GameListTypeLabel on GameListType {
  String get label => switch (this) {
    GameListType.library => 'Biblioteca',
    GameListType.wishlist => 'Lista de desejos',
  };

  String get storageKey => name;
}

extension GameStatusLabel on GameStatus {
  String get label => switch (this) {
    GameStatus.playing => 'Jogando',
    GameStatus.completed => 'Concluído',
    GameStatus.dropped => 'Abandonado',
  };
}

extension GameSourceLabel on GameSource {
  String get label => switch (this) {
    GameSource.manual => 'Manual',
    GameSource.steam => 'Steam',
    GameSource.epic => 'Epic Games',
    GameSource.rawg => 'RAWG',
  };
}

extension GameSortModeLabel on GameSortMode {
  String get label => switch (this) {
    GameSortMode.ratingAscending => 'Nota: menor primeiro',
    GameSortMode.ratingDescending => 'Nota: maior primeiro',
    GameSortMode.nameAscending => 'Nome: A–Z',
    GameSortMode.nameDescending => 'Nome: Z–A',
    GameSortMode.playtimeAscending => 'Horas: menor primeiro',
    GameSortMode.playtimeDescending => 'Horas: maior primeiro',
    GameSortMode.manual => 'Ordem manual',
  };

  bool get isRating =>
      this == GameSortMode.ratingAscending ||
      this == GameSortMode.ratingDescending;

  bool get isPlaytime =>
      this == GameSortMode.playtimeAscending ||
      this == GameSortMode.playtimeDescending;

  bool get isDescending =>
      this == GameSortMode.ratingDescending ||
      this == GameSortMode.nameDescending ||
      this == GameSortMode.playtimeDescending;
}

class Game {
  const Game({
    required this.id,
    required this.name,
    required this.platformId,
    required this.listType,
    required this.createdAt,
    required this.updatedAt,
    this.externalGameId,
    this.source = GameSource.manual,
    this.sourceGameId,
    this.coverUrl,
    this.rating,
    this.playtimeMinutes,
    this.startDate,
    this.completionDate,
    this.status,
    this.manualPosition = 0,
    this.deletedAt,
    this.localSyncStatus = 'pending',
    this.remoteVersion,
  });

  final String id;
  final String? externalGameId;
  final GameSource source;
  final String? sourceGameId;
  final String name;
  final String? coverUrl;
  final String platformId;
  final double? rating;
  final int? playtimeMinutes;
  final DateTime? startDate;
  final DateTime? completionDate;
  final GameStatus? status;
  final GameListType listType;
  final int manualPosition;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String localSyncStatus;
  final int? remoteVersion;

  double? get playtimeHours =>
      playtimeMinutes == null ? null : playtimeMinutes! / 60;

  Map<String, Object?> toJson() => {
    'id': id,
    'externalGameId': externalGameId,
    'source': source.name,
    'sourceGameId': sourceGameId,
    'name': name,
    'coverUrl': coverUrl,
    'platformId': platformId,
    'rating': rating,
    'playtimeMinutes': playtimeMinutes,
    'startDate': startDate?.toIso8601String(),
    'completionDate': completionDate?.toIso8601String(),
    'status': status?.name,
    'listType': listType.name,
    'manualPosition': manualPosition,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'localSyncStatus': localSyncStatus,
    'remoteVersion': remoteVersion,
  };

  factory Game.fromRow(Map<String, Object?> row) => Game(
    id: row['id']! as String,
    externalGameId: row['external_game_id'] as String?,
    source: GameSource.values.byName(row['source']! as String),
    sourceGameId: row['source_game_id'] as String?,
    name: row['name']! as String,
    coverUrl: row['cover_url'] as String?,
    platformId: row['platform_id']! as String,
    rating: (row['rating'] as num?)?.toDouble(),
    playtimeMinutes: row['playtime_minutes'] as int?,
    startDate: _date(row['start_date']),
    completionDate: _date(row['completion_date']),
    status: row['status'] == null
        ? null
        : GameStatus.values.byName(row['status']! as String),
    listType: GameListType.values.byName(row['list_type']! as String),
    manualPosition: row['manual_position']! as int,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    deletedAt: _date(row['deleted_at']),
    localSyncStatus: row['local_sync_status']! as String,
    remoteVersion: row['remote_version'] as int?,
  );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

class GameDraft {
  const GameDraft({
    required this.name,
    required this.platformId,
    required this.listType,
    required this.source,
    this.externalGameId,
    this.sourceGameId,
    this.coverUrl,
    this.rating,
    this.playtimeMinutes,
    this.startDate,
    this.completionDate,
    this.status,
  });

  final String name;
  final String platformId;
  final GameListType listType;
  final GameSource source;
  final String? externalGameId;
  final String? sourceGameId;
  final String? coverUrl;
  final double? rating;
  final int? playtimeMinutes;
  final DateTime? startDate;
  final DateTime? completionDate;
  final GameStatus? status;
}

const gamePlatforms = <(String, String)>[
  ('pc', 'PC'),
  ('xbox', 'Xbox'),
  ('playstation', 'PlayStation'),
  ('nintendo', 'Nintendo'),
  ('other', 'Outros'),
];

String platformFamilyId(String id) {
  final normalized = id.trim().toLowerCase();
  if (normalized == 'pc' || normalized.contains('windows')) return 'pc';
  if (normalized.contains('xbox')) return 'xbox';
  if (normalized.contains('playstation') || normalized.startsWith('ps')) {
    return 'playstation';
  }
  if (normalized.contains('nintendo') ||
      normalized.contains('switch') ||
      normalized.contains('wii')) {
    return 'nintendo';
  }
  return 'other';
}

String platformLabel(String id) {
  final legacyLabel = switch (id) {
    'xbox_360' => 'Xbox 360',
    'xbox_one' || 'xbox_one_s' => 'Xbox One',
    'xbox_series_s' => 'Xbox Series S',
    'xbox_series_x' => 'Xbox Series X',
    'playstation_3' => 'PlayStation 3',
    'playstation_4' => 'PlayStation 4',
    'playstation_5' => 'PlayStation 5',
    'nintendo_switch' => 'Nintendo Switch',
    'nintendo_switch_2' => 'Nintendo Switch 2',
    _ => null,
  };
  if (legacyLabel != null) return legacyLabel;

  final familyId = platformFamilyId(id);
  for (final platform in gamePlatforms) {
    if (platform.$1 == familyId) return platform.$2;
  }
  return 'Outros';
}
