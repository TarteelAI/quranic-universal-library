const PARAM_START = "start_time";
const PARAM_END = "end_time";

function parseMs(value) {
  if (value === null || value === undefined || value === "") return null;
  const num = Number(value);
  return Number.isFinite(num) && num >= 0 ? num : null;
}

export function readPlayRange() {
  if (typeof window === "undefined" || !window.location) {
    return { start: null, end: null };
  }

  const params = new URLSearchParams(window.location.search);
  return {
    start: parseMs(params.get(PARAM_START)),
    end: parseMs(params.get(PARAM_END)),
  };
}

export function writePlayRange(start, end) {
  if (typeof window === "undefined" || !window.history || !window.location) return;

  const url = new URL(window.location.href);

  const apply = (key, value) => {
    if (value === null || value === undefined || value === "") {
      url.searchParams.delete(key);
    } else {
      url.searchParams.set(key, value);
    }
  };

  apply(PARAM_START, start);
  apply(PARAM_END, end);

  window.history.replaceState(window.history.state, "", url);
}
