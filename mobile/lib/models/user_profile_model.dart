class MatchHistoryRecord {
  final String date;
  final String category;
  final int rank;
  final int totalPlayers;
  final int itemsWon;

  const MatchHistoryRecord({
    required this.date,
    required this.category,
    required this.rank,
    required this.totalPlayers,
    required this.itemsWon,
  });
}

class UserProfileModel {
  final String username;
  final String avatarInitials;
  final int matchesPlayed;
  final int auctionWins;
  final int itemsPurchased;
  final double winRate;
  final List<MatchHistoryRecord> history;

  const UserProfileModel({
    required this.username,
    required this.avatarInitials,
    required this.matchesPlayed,
    required this.auctionWins,
    required this.itemsPurchased,
    required this.winRate,
    required this.history,
  });
}
