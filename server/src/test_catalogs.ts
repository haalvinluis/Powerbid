import { AuctionItemDTO } from '../../shared/socket_events';

export const CRICKET_TEST_CATALOG: AuctionItemDTO[] = [
  { id: 'c1', name: 'Virat Kohli', displayName: 'Virat Kohli', categoryId: 'cricket', category: 'Cricket', basePrice: 200, powerPoints: 96, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c2', name: 'Rohit Sharma', displayName: 'Rohit Sharma', categoryId: 'cricket', category: 'Cricket', basePrice: 200, powerPoints: 93, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c3', name: 'MS Dhoni', displayName: 'MS Dhoni', categoryId: 'cricket', category: 'Cricket', basePrice: 200, powerPoints: 94, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c4', name: 'Jasprit Bumrah', displayName: 'Jasprit Bumrah', categoryId: 'cricket', category: 'Cricket', basePrice: 150, powerPoints: 95, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c5', name: 'Ravindra Jadeja', displayName: 'Ravindra Jadeja', categoryId: 'cricket', category: 'Cricket', basePrice: 150, powerPoints: 90, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c6', name: 'AB de Villiers', displayName: 'AB de Villiers', categoryId: 'cricket', category: 'Cricket', basePrice: 180, powerPoints: 95, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c7', name: 'Ben Stokes', displayName: 'Ben Stokes', categoryId: 'cricket', category: 'Cricket', basePrice: 170, powerPoints: 92, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c8', name: 'Rashid Khan', displayName: 'Rashid Khan', categoryId: 'cricket', category: 'Cricket', basePrice: 150, powerPoints: 92, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c9', name: 'Steve Smith', displayName: 'Steve Smith', categoryId: 'cricket', category: 'Cricket', basePrice: 160, powerPoints: 94, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
  { id: 'c10', name: 'Kane Williamson', displayName: 'Kane Williamson', categoryId: 'cricket', category: 'Cricket', basePrice: 160, powerPoints: 91, scoringMethod: 'ICC Stats', provenance: 'ICC Records', isActive: true },
];

export const NARUTO_TEST_CATALOG: AuctionItemDTO[] = [
  { id: 'n1', name: 'Naruto Uzumaki', displayName: 'Naruto Uzumaki', categoryId: 'naruto', category: 'Naruto', basePrice: 250, powerPoints: 98, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n2', name: 'Sasuke Uchiha', displayName: 'Sasuke Uchiha', categoryId: 'naruto', category: 'Naruto', basePrice: 250, powerPoints: 98, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n3', name: 'Kakashi Hatake', displayName: 'Kakashi Hatake', categoryId: 'naruto', category: 'Naruto', basePrice: 200, powerPoints: 92, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n4', name: 'Itachi Uchiha', displayName: 'Itachi Uchiha', categoryId: 'naruto', category: 'Naruto', basePrice: 240, powerPoints: 94, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n5', name: 'Jiraiya', displayName: 'Jiraiya', categoryId: 'naruto', category: 'Naruto', basePrice: 210, powerPoints: 90, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n6', name: 'Madara Uchiha', displayName: 'Madara Uchiha', categoryId: 'naruto', category: 'Naruto', basePrice: 260, powerPoints: 99, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n7', name: 'Minato Namikaze', displayName: 'Minato Namikaze', categoryId: 'naruto', category: 'Naruto', basePrice: 230, powerPoints: 94, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n8', name: 'Gaara', displayName: 'Gaara', categoryId: 'naruto', category: 'Naruto', basePrice: 180, powerPoints: 88, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n9', name: 'Shikamaru Nara', displayName: 'Shikamaru Nara', categoryId: 'naruto', category: 'Naruto', basePrice: 170, powerPoints: 84, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
  { id: 'n10', name: 'Tsunade Senju', displayName: 'Tsunade Senju', categoryId: 'naruto', category: 'Naruto', basePrice: 190, powerPoints: 88, scoringMethod: 'Ninja Rubric', provenance: 'Databooks', isActive: true },
];

export const ANIME_TEST_CATALOG: AuctionItemDTO[] = [
  { id: 'a1', name: 'Goku', displayName: 'Goku', categoryId: 'dragon_ball', category: 'Dragon Ball', basePrice: 300, powerPoints: 99, scoringMethod: 'Battle Power', provenance: 'Daizenshuu', isActive: true },
  { id: 'a2', name: 'Saitama', displayName: 'Saitama', categoryId: 'other_anime', category: 'Other Anime', basePrice: 300, powerPoints: 100, scoringMethod: 'Cross-Anime', provenance: 'Official Guide', isActive: true },
  { id: 'a3', name: 'Monkey D. Luffy', displayName: 'Monkey D. Luffy', categoryId: 'one_piece', category: 'One Piece', basePrice: 280, powerPoints: 97, scoringMethod: 'Combat Power', provenance: 'Vivre Cards', isActive: true },
  { id: 'a4', name: 'Roronoa Zoro', displayName: 'Roronoa Zoro', categoryId: 'one_piece', category: 'One Piece', basePrice: 240, powerPoints: 94, scoringMethod: 'Combat Power', provenance: 'Vivre Cards', isActive: true },
  { id: 'a5', name: 'Levi Ackerman', displayName: 'Levi Ackerman', categoryId: 'other_anime', category: 'Other Anime', basePrice: 250, powerPoints: 89, scoringMethod: 'Cross-Anime', provenance: 'Official Guide', isActive: true },
  { id: 'a6', name: 'Satoru Gojo', displayName: 'Satoru Gojo', categoryId: 'jujutsu_kaisen', category: 'Jujutsu Kaisen', basePrice: 290, powerPoints: 99, scoringMethod: 'Sorcerer Grade', provenance: 'Fanbook', isActive: true },
  { id: 'a7', name: 'Light Yagami', displayName: 'Light Yagami', categoryId: 'other_anime', category: 'Other Anime', basePrice: 210, powerPoints: 85, scoringMethod: 'Cross-Anime', provenance: 'Official Guide', isActive: true },
  { id: 'a8', name: 'Edward Elric', displayName: 'Edward Elric', categoryId: 'other_anime', category: 'Other Anime', basePrice: 200, powerPoints: 87, scoringMethod: 'Cross-Anime', provenance: 'Official Guide', isActive: true },
  { id: 'a9', name: 'Eren Yeager', displayName: 'Eren Yeager', categoryId: 'other_anime', category: 'Other Anime', basePrice: 230, powerPoints: 93, scoringMethod: 'Cross-Anime', provenance: 'Official Guide', isActive: true },
  { id: 'a10', name: 'Ichigo Kurosaki', displayName: 'Ichigo Kurosaki', categoryId: 'other_anime', category: 'Other Anime', basePrice: 220, powerPoints: 96, scoringMethod: 'Cross-Anime', provenance: 'Official Guide', isActive: true },
];

export function getTestCatalog(category: string, count: number): AuctionItemDTO[] {
  let source: AuctionItemDTO[];
  switch (category.toLowerCase()) {
    case 'cricket':
      source = CRICKET_TEST_CATALOG;
      break;
    case 'naruto':
      source = NARUTO_TEST_CATALOG;
      break;
    case 'anime':
    default:
      source = ANIME_TEST_CATALOG;
      break;
  }

  const result: AuctionItemDTO[] = [];
  for (let i = 0; i < count; i++) {
    const template = source[i % source.length];
    result.push({
      ...template,
      id: `${template.id}_${i + 1}`,
      name: count > source.length ? `${template.name} #${i + 1}` : template.name,
      displayName: count > source.length ? `${template.displayName} #${i + 1}` : template.displayName,
    });
  }
  return result;
}
