import 'player_model.dart';

class AuctionItemModel {
  final String id;
  final String name;
  final String displayName;
  final String category;
  final int powerPoints;
  final String scoringMethod;
  final String provenance;
  final int basePrice;

  const AuctionItemModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.category,
    required this.powerPoints,
    required this.scoringMethod,
    required this.provenance,
    required this.basePrice,
  });

  factory AuctionItemModel.fromJson(Map<String, dynamic> json) {
    final nameStr = json['displayName'] ?? json['name'] ?? '';
    return AuctionItemModel(
      id: json['id'] ?? '',
      name: nameStr,
      displayName: nameStr,
      category: json['categoryId'] ?? json['category'] ?? '',
      powerPoints: json['powerPoints'] ?? 0,
      scoringMethod: json['scoringMethod'] ?? 'Standard Rating Scale (0-100)',
      provenance: json['provenance'] ?? 'Verified Official Reference Data',
      basePrice: json['basePrice'] ?? 0,
    );
  }
}

class StandingsRecordModel {
  final int rank;
  final String playerId;
  final String playerName;
  final int itemsWon;
  final int totalTeamPoints;
  final List<Map<String, dynamic>> itemsList;
  final int remainingBudget;

  const StandingsRecordModel({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.itemsWon,
    required this.totalTeamPoints,
    required this.itemsList,
    required this.remainingBudget,
  });

  factory StandingsRecordModel.fromJson(Map<String, dynamic> json) {
    final rawList = (json['itemsList'] as List<dynamic>?) ?? [];
    final itemsList = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return StandingsRecordModel(
      rank: json['rank'] ?? 1,
      playerId: json['playerId'] ?? '',
      playerName: json['playerName'] ?? '',
      itemsWon: json['itemsWon'] ?? 0,
      totalTeamPoints: json['totalTeamPoints'] ?? json['totalPowerPoints'] ?? 0,
      itemsList: itemsList,
      remainingBudget: json['remainingBudget'] ?? 0,
    );
  }
}

class AuctionStateModel {
  final String roomCode;
  final String gameMode; // 'POWER_COMPARISON' | 'AUCTION_TEAM_CHALLENGE'
  final String phase; // 'LOBBY' | 'ITEM_ANNOUNCED' | 'BIDDING' | 'SOLD' | 'UNSOLD' | 'COMPLETED'
  final int currentItemIndex;
  final int totalItems;
  final AuctionItemModel? currentItem;
  final int currentBid;
  final int minNextBid;
  final String? leadingBidderId;
  final String? leadingBidderName;
  final int timerDuration;
  final int timerSecondsRemaining;
  final List<String> passedPlayerIds;
  final List<PlayerModel> players;
  final List<StandingsRecordModel> standings;

  const AuctionStateModel({
    required this.roomCode,
    this.gameMode = 'AUCTION_TEAM_CHALLENGE',
    required this.phase,
    required this.currentItemIndex,
    required this.totalItems,
    this.currentItem,
    required this.currentBid,
    required this.minNextBid,
    this.leadingBidderId,
    this.leadingBidderName,
    this.timerDuration = 15,
    required this.timerSecondsRemaining,
    required this.passedPlayerIds,
    required this.players,
    this.standings = const [],
  });

  factory AuctionStateModel.fromJson(Map<String, dynamic> json) {
    final playersList = (json['players'] as List<dynamic>?)
            ?.map((p) => PlayerModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    final passedList = (json['passedPlayerIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final standingsList = (json['standings'] as List<dynamic>?)
            ?.map((s) => StandingsRecordModel.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return AuctionStateModel(
      roomCode: json['roomCode'] ?? '',
      gameMode: json['gameMode'] ?? 'AUCTION_TEAM_CHALLENGE',
      phase: json['phase'] ?? 'LOBBY',
      currentItemIndex: json['currentItemIndex'] ?? 0,
      totalItems: json['totalItems'] ?? 0,
      currentItem: json['currentItem'] != null
          ? AuctionItemModel.fromJson(json['currentItem'])
          : null,
      currentBid: json['currentBid'] ?? 0,
      minNextBid: json['minNextBid'] ?? 0,
      leadingBidderId: json['leadingBidderId'],
      leadingBidderName: json['leadingBidderName'],
      timerDuration: json['timerDuration'] ?? 15,
      timerSecondsRemaining: json['timerSecondsRemaining'] ?? 15,
      passedPlayerIds: passedList,
      players: playersList,
      standings: standingsList,
    );
  }
}
