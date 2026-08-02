export function getBoardSubtitle(date: Date = new Date()): string {
  const hour = date.getHours();

  if (hour >= 5 && hour < 12) return "Morning's Board";
  if (hour >= 12 && hour < 17) return "Afternoon's Board";
  return "Tonight's Board";
}
