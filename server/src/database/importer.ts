import { CharacterRecord } from './schema';

export interface ImportReport {
  totalProcessed: number;
  validCount: number;
  duplicateCount: number;
  invalidCount: number;
  invalidRecords: { record: any; reason: string }[];
  validRecords: CharacterRecord[];
}

export class DataImporter {
  public static processAndValidate(rawRecords: any[]): ImportReport {
    const validRecords: CharacterRecord[] = [];
    const invalidRecords: { record: any; reason: string }[] = [];
    const seenKeys = new Set<string>();

    let duplicateCount = 0;

    for (const raw of rawRecords) {
      // Name validation
      if (!raw || typeof raw.displayName !== 'string' || raw.displayName.trim().length === 0) {
        invalidRecords.push({ record: raw, reason: 'Invalid or missing display name' });
        continue;
      }

      const nameClean = raw.displayName.trim();
      const catId = (raw.categoryId || 'unknown').toLowerCase();
      const uniqueKey = `${catId}:${nameClean.toLowerCase()}`;

      // Duplicate check
      if (seenKeys.has(uniqueKey)) {
        duplicateCount++;
        invalidRecords.push({ record: raw, reason: `Duplicate record: ${nameClean}` });
        continue;
      }

      // Power points validation (0-100 integer)
      const points = raw.powerPoints;
      if (
        typeof points !== 'number' ||
        !Number.isInteger(points) ||
        points < 0 ||
        points > 100
      ) {
        invalidRecords.push({
          record: raw,
          reason: `Power points must be integer between 0 and 100 (got: ${points})`,
        });
        continue;
      }

      seenKeys.add(uniqueKey);

      validRecords.push({
        id: raw.id || `char_${validRecords.length + 1}`,
        categoryId: catId,
        displayName: nameClean,
        name: nameClean,
        powerPoints: points,
        scoringMethod: raw.scoringMethod || 'Standard Rating Scale (0-100)',
        provenance: raw.provenance || 'Verified Official Reference Data',
        isActive: raw.isActive !== false,
        basePrice: raw.basePrice || Math.max(100, Math.floor(points * 3)),
      });
    }

    return {
      totalProcessed: rawRecords.length,
      validCount: validRecords.length,
      duplicateCount,
      invalidCount: invalidRecords.length,
      invalidRecords,
      validRecords,
    };
  }
}
