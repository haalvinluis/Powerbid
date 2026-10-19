import 'player_model.dart';
import 'item_model.dart';

class RoomModel {
  final String roomCode;
  final String category;
  final String gameMode;
  final int totalItems;
  final int timerDuration;
  final int maxPlayers;
  final String hostId;
  final List<PlayerModel> players;
  final List<ItemModel> items;
  final int currentItemIndex;
  final int currentBid;
  final String? leadingBidderId;

  const RoomModel({
    required this.roomCode,
    required this.category,
    this.gameMode = 'AUCTION_TEAM_CHALLENGE',
    required this.totalItems,
    this.timerDuration = 15,
    this.maxPlayers = 8,
    required this.hostId,
    required this.players,
    required this.items,
    this.currentItemIndex = 0,
    this.currentBid = 0,
    this.leadingBidderId,
  });

  ItemModel? get currentItem =>
      (currentItemIndex < items.length) ? items[currentItemIndex] : null;

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'cricket':
        return 'Cricket';
      case 'naruto':
        return 'Naruto';
      case 'one_piece':
        return 'One Piece';
      case 'dragon_ball':
        return 'Dragon Ball';
      case 'pokemon':
        return 'Pokémon';
      case 'demon_slayer':
        return 'Demon Slayer';
      case 'jujutsu_kaisen':
        return 'Jujutsu Kaisen';
      case 'classic_cartoons':
        return 'Classic Cartoons';
      case 'superheroes':
        return 'Superheroes';
      case 'marvel_avengers':
        return 'Marvel Avengers';
      case 'other_anime':
      default:
        return 'Other Anime';
    }
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final playersList = (json['players'] as List<dynamic>?)
            ?.map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return RoomModel(
      roomCode: json['roomCode'] ?? '',
      category: json['category'] ?? 'cricket',
      gameMode: json['gameMode'] ?? 'AUCTION_TEAM_CHALLENGE',
      totalItems: json['itemCount'] ?? 10,
      timerDuration: json['timerDuration'] ?? 15,
      maxPlayers: json['maxPlayers'] ?? 8,
      hostId: json['hostId'] ?? '',
      players: playersList,
      items: const [],
      currentItemIndex: json['currentItemIndex'] ?? 0,
      currentBid: json['currentBid'] ?? 0,
      leadingBidderId: json['leadingBidderId'],
    );
  }
}
