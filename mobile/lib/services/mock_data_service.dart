import '../models/player_model.dart';
import '../models/item_model.dart';
import '../models/room_model.dart';
import '../models/user_profile_model.dart';

class MockDataService {
  static const List<ItemModel> cricketItems = [
    ItemModel(id: 'c1', name: 'Virat Kohli', category: 'Cricket', basePrice: 200),
    ItemModel(id: 'c2', name: 'Rohit Sharma', category: 'Cricket', basePrice: 200),
    ItemModel(id: 'c3', name: 'MS Dhoni', category: 'Cricket', basePrice: 200),
    ItemModel(id: 'c4', name: 'Jasprit Bumrah', category: 'Cricket', basePrice: 150),
    ItemModel(id: 'c5', name: 'Ravindra Jadeja', category: 'Cricket', basePrice: 150),
    ItemModel(id: 'c6', name: 'AB de Villiers', category: 'Cricket', basePrice: 180),
    ItemModel(id: 'c7', name: 'Ben Stokes', category: 'Cricket', basePrice: 170),
    ItemModel(id: 'c8', name: 'Rashid Khan', category: 'Cricket', basePrice: 150),
    ItemModel(id: 'c9', name: 'Steve Smith', category: 'Cricket', basePrice: 160),
    ItemModel(id: 'c10', name: 'Kane Williamson', category: 'Cricket', basePrice: 160),
  ];

  static const List<ItemModel> narutoItems = [
    ItemModel(id: 'n1', name: 'Naruto Uzumaki', category: 'Naruto', basePrice: 250),
    ItemModel(id: 'n2', name: 'Sasuke Uchiha', category: 'Naruto', basePrice: 250),
    ItemModel(id: 'n3', name: 'Kakashi Hatake', category: 'Naruto', basePrice: 200),
    ItemModel(id: 'n4', name: 'Itachi Uchiha', category: 'Naruto', basePrice: 240),
    ItemModel(id: 'n5', name: 'Jiraiya', category: 'Naruto', basePrice: 210),
    ItemModel(id: 'n6', name: 'Madara Uchiha', category: 'Naruto', basePrice: 260),
    ItemModel(id: 'n7', name: 'Minato Namikaze', category: 'Naruto', basePrice: 230),
    ItemModel(id: 'n8', name: 'Gaara', category: 'Naruto', basePrice: 180),
    ItemModel(id: 'n9', name: 'Shikamaru Nara', category: 'Naruto', basePrice: 170),
    ItemModel(id: 'n10', name: 'Tsunade Senju', category: 'Naruto', basePrice: 190),
  ];

  static const List<ItemModel> animeItems = [
    ItemModel(id: 'a1', name: 'Goku', category: 'Anime', basePrice: 300),
    ItemModel(id: 'a2', name: 'Saitama', category: 'Anime', basePrice: 300),
    ItemModel(id: 'a3', name: 'Monkey D. Luffy', category: 'Anime', basePrice: 280),
    ItemModel(id: 'a4', name: 'Roronoa Zoro', category: 'Anime', basePrice: 240),
    ItemModel(id: 'a5', name: 'Levi Ackerman', category: 'Anime', basePrice: 250),
    ItemModel(id: 'a6', name: 'Satoru Gojo', category: 'Anime', basePrice: 290),
    ItemModel(id: 'a7', name: 'Light Yagami', category: 'Anime', basePrice: 210),
    ItemModel(id: 'a8', name: 'Edward Elric', category: 'Anime', basePrice: 200),
    ItemModel(id: 'a9', name: 'Eren Yeager', category: 'Anime', basePrice: 230),
    ItemModel(id: 'a10', name: 'Ichigo Kurosaki', category: 'Anime', basePrice: 220),
  ];

  static List<PlayerModel> getMockLobbyPlayers(String hostName) {
    return [
      PlayerModel(id: 'p1', name: hostName, isHost: true, isReady: true, budget: 1000),
      const PlayerModel(id: 'p2', name: 'ShadowStriker', isReady: true, budget: 1000),
      const PlayerModel(id: 'p3', name: 'VortexMaster', isReady: true, budget: 1000),
      const PlayerModel(id: 'p4', name: 'BlazeRider', isReady: false, budget: 1000),
    ];
  }

  static UserProfileModel getMockUserProfile() {
    return const UserProfileModel(
      username: 'AuctionLegend_99',
      avatarInitials: 'AL',
      matchesPlayed: 42,
      auctionWins: 18,
      itemsPurchased: 135,
      winRate: 42.8,
      history: [
        MatchHistoryRecord(date: 'Oct 08, 2026', category: 'Cricket', rank: 1, totalPlayers: 8, itemsWon: 4),
        MatchHistoryRecord(date: 'Oct 06, 2026', category: 'Naruto', rank: 2, totalPlayers: 6, itemsWon: 3),
        MatchHistoryRecord(date: 'Oct 03, 2026', category: 'Anime', rank: 1, totalPlayers: 8, itemsWon: 5),
        MatchHistoryRecord(date: 'Sep 29, 2026', category: 'Cricket', rank: 3, totalPlayers: 8, itemsWon: 2),
      ],
    );
  }

  static RoomModel getSampleRoom(String category, int totalItems) {
    List<ItemModel> pool = cricketItems;
    if (category.toLowerCase() == 'naruto') {
      pool = narutoItems;
    } else if (category.toLowerCase() == 'anime' || category.toLowerCase() == 'other_anime') {
      pool = animeItems;
    }

    final players = [
      const PlayerModel(id: 'p1', name: 'AuctionLegend_99', isHost: true, budget: 650, acquiredItems: ['Virat Kohli']),
      const PlayerModel(id: 'p2', name: 'ShadowStriker', budget: 450, acquiredItems: ['MS Dhoni']),
      const PlayerModel(id: 'p3', name: 'VortexMaster', budget: 800, acquiredItems: []),
      const PlayerModel(id: 'p4', name: 'BlazeRider', budget: 300, acquiredItems: ['Rohit Sharma']),
    ];

    return RoomModel(
      roomCode: 'ARC-789',
      category: category,
      totalItems: totalItems,
      maxPlayers: 8,
      hostId: 'p1',
      players: players,
      items: pool,
      currentItemIndex: 2,
      currentBid: 320,
      leadingBidderId: 'p1',
    );
  }
}
