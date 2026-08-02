export function getBoardSubtitle(date: Date = new Date()): string {
  const hour = date.getHours();

  if (hour >= 5 && hour < 12) return "This Morning's Board";
  if (hour >= 12 && hour < 17) return "This Afternoon's Board";
  return "Tonight's Board";
}
