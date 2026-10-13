// Pure helpers for the monthly leaderboard archive/reset.
// No firebase deps on purpose: they are dry-run testable with plain
// `node functions/test_monthly_reset.js` and reused by functions/index.js.

function monthKeyFromDate(date) {
    return date.toISOString().slice(0, 7);
}

function prevMonthKey(monthKey) {
    const [y, m] = monthKey.split("-").map(Number);
    return new Date(Date.UTC(y, m - 2, 1)).toISOString().slice(0, 7);
}

function monthNameFor(monthKey) {
    const monthNames = ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"];
    const [y, m] = monthKey.split("-").map(Number);
    return `${monthNames[m - 1]} ${y}`;
}

/**
 * A monthly value belongs to `monthKey` when its period stamp is missing
 * (legacy docs) or not newer than monthKey.
 *
 * Rows stamped with a LATER month were accumulated AFTER the rollover — a
 * late scheduler run must not archive them under the old key nor zero them.
 */
function belongsToMonth(stamp, monthKey) {
    return typeof stamp !== "string" || stamp.length === 0 || stamp <= monthKey;
}

function filterRowsForMonth(rows, monthKey, stampField) {
    return rows.filter((r) => belongsToMonth(r[stampField], monthKey));
}

module.exports = { monthKeyFromDate, prevMonthKey, monthNameFor, belongsToMonth, filterRowsForMonth };
