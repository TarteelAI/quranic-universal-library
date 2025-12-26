const STORAGE_KEY = "qul:ayah_modal";

function readRaw() {
  try {
    const v = window.localStorage.getItem(STORAGE_KEY);
    if (!v) return {};
    const parsed = JSON.parse(v);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch (_) {
    return {};
  }
}

function writeRaw(next) {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch (_) {
  }
}

export function getAyahModalPrefs() {
  const raw = readRaw();
  const prefs = raw.prefs && typeof raw.prefs === "object" ? raw.prefs : {};
  return {
    script: typeof prefs.script === "string" ? prefs.script : null,
    translationIds: Array.isArray(prefs.translationIds) ? prefs.translationIds : null,
    tafsirIds: Array.isArray(prefs.tafsirIds) ? prefs.tafsirIds : null,
    wordTranslationId: Number.isInteger(prefs.wordTranslationId) ? prefs.wordTranslationId : null,
  };
}

export function setAyahModalPrefs(partial) {
  const raw = readRaw();
  const existing = raw.prefs && typeof raw.prefs === "object" ? raw.prefs : {};
  const nextPrefs = { ...existing, ...partial };
  writeRaw({ ...raw, prefs: nextPrefs });
}


