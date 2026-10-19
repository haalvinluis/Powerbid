class PlayerModel {
  final String id;
  final String? sessionToken;
  final String name;
  final bool isHost;
  final bool isReady;
  final int budget;
  final List<String> acquiredItems;
  final bool isConnected;

  const PlayerModel({
    required this.id,
    this.sessionToken,
    required this.name,
    this.isHost = false,
    this.isReady = false,
    this.budget = 1000,
    this.acquiredItems = const [],
    this.isConnected = true,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] ?? '',
      sessionToken: json['sessionToken'],
      name: json['name'] ?? 'Player',
      isHost: json['isHost'] ?? false,
      isReady: json['isReady'] ?? true,
      budget: json['budget'] ?? 1000,
      acquiredItems: (json['acquiredItems'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isConnected: json['isConnected'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (sessionToken != null) 'sessionToken': sessionToken,
      'name': name,
      'isHost': isHost,
      'isReady': isReady,
      'budget': budget,
      'acquiredItems': acquiredItems,
      'isConnected': isConnected,
    };
  }

  PlayerModel copyWith({
    String? id,
    String? name,
    bool? isHost,
    bool? isReady,
    int? budget,
    List<String>? acquiredItems,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      budget: budget ?? this.budget,
      acquiredItems: acquiredItems ?? this.acquiredItems,
    );
  }
}
