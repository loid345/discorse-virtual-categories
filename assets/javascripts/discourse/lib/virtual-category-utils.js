export function parseVirtualCategoryList(raw) {
  if (!raw) {
    return [];
  }
  if (Array.isArray(raw)) {
    return raw;
  }
  if (typeof raw === "string") {
    return raw.split("|").filter(Boolean);
  }
  return [];
}
