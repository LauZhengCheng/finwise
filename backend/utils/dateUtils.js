// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : dateUtils.js
// Description   : Malaysia timezone (UTC+8) date utilities.
//                 All date calculations that depend on "today" must use
//                 these helpers to ensure correctness on Cloud Run (UTC).
// First Written : 21-06-2026
// Edited on     : 21-06-2026
// ============================================

const TZ = 'Asia/Kuala_Lumpur';

// Get current date/time in Malaysia timezone
function nowMYT() {
  return new Date(new Date().toLocaleString('en-US', { timeZone: TZ }));
}

// Get day of month in Malaysia timezone (1-31)
function dayOfMonthMYT() {
  return nowMYT().getDate();
}

// Get total days in current month (Malaysia timezone)
function daysInMonthMYT() {
  const d = nowMYT();
  return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
}

// Get days left in the month (Malaysia timezone)
function daysLeftMYT() {
  return daysInMonthMYT() - dayOfMonthMYT();
}

// Get month progress percentage (Malaysia timezone)
function monthProgressMYT() {
  return Math.round((dayOfMonthMYT() / daysInMonthMYT()) * 100);
}

// Get full month context object for prompts and calculations
function getMonthContext() {
  const day = dayOfMonthMYT();
  const total = daysInMonthMYT();
  const left = total - day;
  const pct = Math.round((day / total) * 100);
  return { day, total, left, pct };
}

// Get midnight today in Malaysia timezone as ISO string
function midnightTodayMYT() {
  const d = nowMYT();
  d.setHours(0, 0, 0, 0);
  return d.toISOString();
}

// Format current date/time for display in Malaysia locale
function formatNowMYT() {
  return new Date().toLocaleString('en-MY', {
    timeZone: TZ,
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

// Format any date to Malaysia locale date string
function formatDateMYT(date, options = {}) {
  return new Date(date).toLocaleDateString('en-MY', { timeZone: TZ, ...options });
}

// Format any date to Malaysia locale date+time string
function formatDateTimeMYT(date) {
  return new Date(date).toLocaleString('en-MY', {
    timeZone: TZ,
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

module.exports = {
  TZ,
  nowMYT,
  dayOfMonthMYT,
  daysInMonthMYT,
  daysLeftMYT,
  monthProgressMYT,
  getMonthContext,
  midnightTodayMYT,
  formatNowMYT,
  formatDateMYT,
  formatDateTimeMYT,
};
