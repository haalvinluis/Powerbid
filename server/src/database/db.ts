import { CharacterRecord, CategoryInfo } from './schema';
import { DataImporter, ImportReport } from './importer';
import {
  RAW_CRICKET_DATA,
  RAW_NARUTO_DATA,
  RAW_ONE_PIECE_DATA,
  RAW_DRAGON_BALL_DATA,
  RAW_POKEMON_DATA,
  RAW_DEMON_SLAYER_DATA,
  RAW_JUJUTSU_KAISEN_DATA,
  RAW_CARTOONS_DATA,
  RAW_SUPERHEROES_DATA,
  RAW_AVENGERS_DATA,
  RAW_OTHER_ANIME_DATA,
} from './catalogs';

export interface CategorySummaryDTO {
  id: string;
  name: string;
  actualCount: number;
  targetCount: number;
  isEnough5: boolean;
  isEnough10: boolean;
  isEnough25: boolean;
  scoringMethod: string;
  provenance: string;
}

export class CharacterDatabase {
  private static instance: CharacterDatabase;
  private categoriesMap: Map<string, CategoryInfo> = new Map();
  private recordsMap: Map<string, CharacterRecord[]> = new Map();
  private reportsMap: Map<string, ImportReport> = new Map();

  private constructor() {
    this.initCategories();
    this.loadAndProcessAll();
  }

  public static getInstance(): CharacterDatabase {
    if (!CharacterDatabase.instance) {
      CharacterDatabase.instance = new CharacterDatabase();
    }
    return CharacterDatabase.instance;
  }

  private initCategories(): void {
    const list: CategoryInfo[] = [
      {
        id: 'cricket',
        name: 'Cricket',
        targetCount: 800,
        scoringMethod: 'ICC Career Performance Rating Scale (0-100 based on Batting/Bowling Averages & Strike Rates)',
        provenance: 'ICC Official International Stats & Wisden Records',
      },
      {
        id: 'naruto',
        name: 'Naruto',
        targetCount: 250,
        scoringMethod: 'Fictional Ninja Power Tier Rubric (Chakra levels, Kekkei Genkai, Jutsu mastery)',
        provenance: 'Official Naruto Databooks 1-4 & Canon Manga Ratings',
      },
      {
        id: 'one_piece',
        name: 'One Piece',
        targetCount: 300,
        scoringMethod: 'Combat Power Rubric (Haki proficiency, Devil Fruit Awakening, Bounties)',
        provenance: 'One Piece Vivre Card Databooks & Canon Manga Ratings',
      },
      {
        id: 'dragon_ball',
        name: 'Dragon Ball',
        targetCount: 200,
        scoringMethod: 'Fictional Battle Power Rubric (Ki mastery, Divine forms, Ultra Instinct)',
        provenance: 'Daizenshuu Official Guides & Canon Anime/Manga Ratings',
      },
      {
        id: 'pokemon',
        name: 'Pokémon',
        targetCount: 500,
        scoringMethod: 'Normalized Base Stat Total (BST / 720 * 100 Integer Rating)',
        provenance: 'Official Game Freak Pokémon Video Game Stat Databases',
      },
      {
        id: 'demon_slayer',
        name: 'Demon Slayer',
        targetCount: 150,
        scoringMethod: 'Combat Rank Rubric (Breathing Styles, Hashira/Upper Moon Tiering)',
        provenance: 'Demon Slayer Official Fanbooks 1-2 & Canon Manga Ratings',
      },
      {
        id: 'jujutsu_kaisen',
        name: 'Jujutsu Kaisen',
        targetCount: 150,
        scoringMethod: 'Sorcerer Grade & Cursed Energy Output Rubric (Special Grade to Grade 4)',
        provenance: 'Jujutsu Kaisen Official Fanbook & Canon Manga Ratings',
      },
      {
        id: 'classic_cartoons',
        name: 'Classic Cartoons',
        targetCount: 200,
        scoringMethod: 'Toon Force & Slapstick Durability Game Rating Rubric',
        provenance: 'Animation Studio Character Records & Game Stats',
      },
      {
        id: 'superheroes',
        name: 'Superheroes',
        targetCount: 200,
        scoringMethod: 'Comic Combat Power & Superpower Power Rank Rubric',
        provenance: 'DC Comics Official Character Encyclopedias & Canon Guides',
      },
      {
        id: 'marvel_avengers',
        name: 'Marvel Avengers',
        targetCount: 200,
        scoringMethod: 'Marvel Power Grid Rubric (Intelligence, Strength, Speed, Durability, Energy, Combat)',
        provenance: 'Official Handbook of Marvel Universe & Canon Comic Ratings',
      },
      {
        id: 'other_anime',
        name: 'Other Anime',
        targetCount: 200,
        scoringMethod: 'Cross-Anime Power Rating Scale (Normalized 0-100)',
        provenance: 'Official Anime Databooks & Canon Source Ratings',
      },
    ];

    list.forEach((c) => this.categoriesMap.set(c.id, c));
  }

  private loadAndProcessAll(): void {
    this.importCategoryData('cricket', RAW_CRICKET_DATA);
    this.importCategoryData('naruto', RAW_NARUTO_DATA);
    this.importCategoryData('one_piece', RAW_ONE_PIECE_DATA);
    this.importCategoryData('dragon_ball', RAW_DRAGON_BALL_DATA);
    this.importCategoryData('pokemon', RAW_POKEMON_DATA);
    this.importCategoryData('demon_slayer', RAW_DEMON_SLAYER_DATA);
    this.importCategoryData('jujutsu_kaisen', RAW_JUJUTSU_KAISEN_DATA);
    this.importCategoryData('classic_cartoons', RAW_CARTOONS_DATA);
    this.importCategoryData('superheroes', RAW_SUPERHEROES_DATA);
    this.importCategoryData('marvel_avengers', RAW_AVENGERS_DATA);
    this.importCategoryData('other_anime', RAW_OTHER_ANIME_DATA);
  }

  public importCategoryData(categoryId: string, rawData: any[]): ImportReport {
    const taggedData = rawData.map((item, idx) => ({
      ...item,
      id: `${categoryId}_${idx + 1}`,
      categoryId,
      scoringMethod: this.categoriesMap.get(categoryId)?.scoringMethod,
      provenance: item.provenance || this.categoriesMap.get(categoryId)?.provenance,
    }));

    const report = DataImporter.processAndValidate(taggedData);
    this.reportsMap.set(categoryId, report);
    this.recordsMap.set(categoryId, report.validRecords);

    console.log(
      `[Database Import] ${categoryId}: ${report.validCount} valid records loaded (${report.duplicateCount} duplicates, ${report.invalidCount} invalid)`
    );

    return report;
  }

  public getCategorySummaryList(): CategorySummaryDTO[] {
    const result: CategorySummaryDTO[] = [];
    this.categoriesMap.forEach((info, id) => {
      const validRecords = this.recordsMap.get(id) || [];
      const actualCount = validRecords.length;
      result.push({
        id: info.id,
        name: info.name,
        actualCount,
        targetCount: info.targetCount,
        isEnough5: actualCount >= 5,
        isEnough10: actualCount >= 10,
        isEnough25: actualCount >= 25,
        scoringMethod: info.scoringMethod,
        provenance: info.provenance,
      });
    });
    return result;
  }

  public getCategorySummary(categoryId: string): CategorySummaryDTO | undefined {
    let cleanId = categoryId.toLowerCase();
    if (cleanId === 'anime') cleanId = 'other_anime';
    const list = this.getCategorySummaryList();
    return list.find((c) => c.id === cleanId);
  }

  public getCharacterRecords(categoryId: string, count: number): CharacterRecord[] {
    let cleanId = categoryId.toLowerCase();
    if (cleanId === 'anime') cleanId = 'other_anime';
    const records = this.recordsMap.get(cleanId);

    if (!records || records.length < count) {
      const available = records ? records.length : 0;
      throw new Error(
        `Insufficient valid records in category "${categoryId}". Requested ${count}, but only ${available} valid records exist.`
      );
    }

    // Return unique items slice
    return records.slice(0, count);
  }
}
