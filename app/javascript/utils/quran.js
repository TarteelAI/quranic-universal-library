// First ayah id of all surahs
const FIRST_AYAH = [
  1, 8, 294, 494, 670, 790, 955, 1161, 1236, 1365, 1474, 1597, 1708, 1751, 1803,
  1902, 2030, 2141, 2251, 2349, 2484, 2596, 2674, 2792, 2856, 2933, 3160, 3253,
  3341, 3410, 3470, 3504, 3534, 3607, 3661, 3706, 3789, 3971, 4059, 4134, 4219,
  4273, 4326, 4415, 4474, 4511, 4546, 4584, 4613, 4631, 4676, 4736, 4785, 4847,
  4902, 4980, 5076, 5105, 5127, 5151, 5164, 5178, 5189, 5200, 5218, 5230, 5242,
  5272, 5324, 5376, 5420, 5448, 5476, 5496, 5552, 5592, 5623, 5673, 5713, 5759,
  5801, 5830, 5849, 5885, 5910, 5932, 5949, 5968, 5994, 6024, 6044, 6059, 6080,
  6091, 6099, 6107, 6126, 6131, 6139, 6147, 6158, 6169, 6177, 6180, 6189, 6194,
  6198, 6205, 6208, 6214, 6217, 6222, 6226, 6231, 6236
];

export class QuranUtils {
  static getSurahAyahRange(surah) {
    surah = parseInt(surah, 10);
    if (surah < 1 || surah > 114) return [];
    return [FIRST_AYAH[surah - 1], FIRST_AYAH[surah] - 1];
  }

  static firstAyahOfSurah(verseId) {
    return FIRST_AYAH.includes(verseId);
  }

  static lastAyahOfSurah(ayahKeyOrId) {
    const key = ayahKeyOrId.toString().includes(':') ? ayahKeyOrId : this.getAyahKeyFromId(ayahKeyOrId);
    const [surahNumber, ayahNumber] = key.split(':').map(Number);
    return ayahNumber === this.getSurahAyahCount(surahNumber);
  }

  static getSurahNumberFromVerseId(verseId) {
    for (let i = 0; i < FIRST_AYAH.length - 1; i++) {
      if (verseId >= FIRST_AYAH[i] && verseId < FIRST_AYAH[i + 1]) return i + 1;
    }
    return 114; // last surah
  }

  static getSurahNumberFromVerseKey(key) {
     return parseInt(key.split(':')[0])
  }
  static getAyahNumberFromVerseKey(key) {
    return parseInt(key.split(':')[1])
  }

  static getAyahKeyFromId(verseId) {
    if (verseId == null) return null;
    const surah = this.getSurahNumberFromVerseId(verseId);
    const ayah = verseId - FIRST_AYAH[surah - 1] + 1;
    return `${surah}:${ayah}`;
  }

  static getAyahIdFromKey(key) {
    if (!key) return null;
    const [surah, ayah] = key.split(':').map(Number);
    return this.getAyahId(surah, ayah);
  }

  static getAyahId(surah, ayah) {
    return this.validAyah(surah, ayah) ? FIRST_AYAH[surah - 1] + ayah - 1 : null;
  }

  static getAyahKey(surah, ayah) {
    return `${surah}:${ayah}`;
  }

  static validAyah(surah, ayah) {
    return ayah > 0 && surah > 0 && surah < FIRST_AYAH.length && ayah <= this.getSurahAyahCount(surah);
  }

  static validRange(surah, from, to) {
    surah = parseInt(surah);
    from = parseInt(from);
    to = parseInt(to);
    return surah >= 1 && surah <= 114 && this.validAyah(surah, from) && (to === 0 || this.validAyah(surah, to));
  }

  static getSurahAyahCount(surah) {
    if (surah < 1 || surah >= FIRST_AYAH.length) return null;
    return FIRST_AYAH[surah] - FIRST_AYAH[surah - 1];
  }
}
