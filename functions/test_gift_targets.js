/**
 * Fan-out rules for sendGiftWithCombo (one call, N receivers, one transaction).
 *
 * Run:  node functions/test_gift_targets.js
 *
 * A wrong target list here means diamonds leave the sender and land on the
 * wrong user doc, so these rules are asserted rather than eyeballed.
 */
const assert = require("assert");
const { resolveGiftTargets } = require("./index.js");

const ME = "sender1";

// Legacy single-target shape keeps working (combo bar still sends this way).
assert.deepStrictEqual(resolveGiftTargets({ targetUid: "a" }, ME), ["a"]);

// Fan-out shape.
assert.deepStrictEqual(
    resolveGiftTargets({ targetUids: ["a", "b", "c"] }, ME),
    ["a", "b", "c"]
);

// Both shapes together, order preserved.
assert.deepStrictEqual(
    resolveGiftTargets({ targetUid: "c", targetUids: ["a", "b"] }, ME),
    ["a", "b", "c"]
);

// A sender can never target themselves - the charge would bounce.
assert.deepStrictEqual(
    resolveGiftTargets({ targetUids: ["a", ME, "b"] }, ME),
    ["a", "b"]
);

// Blanks, nulls, non-strings are dropped instead of becoming a doc id.
assert.deepStrictEqual(
    resolveGiftTargets({ targetUids: ["", null, undefined, 42, "a"] }, ME),
    ["a"]
);

// Whitespace is trimmed (a padded id is a different, empty user doc) and
// duplicates collapse AFTER normalisation.
assert.deepStrictEqual(
    resolveGiftTargets({ targetUids: [" a", "a ", "a"] }, ME),
    ["a"]
);

// Nothing selectable -> empty, which the callable rejects as invalid-argument.
assert.deepStrictEqual(resolveGiftTargets({}, ME), []);
assert.deepStrictEqual(resolveGiftTargets({ targetUid: ME, targetUids: [ME] }, ME), []);

// Resolution never truncates: the MAX_TARGETS cap is enforced by the callable
// (an over-sized room must fail loudly, not silently send to the first 40).
const many = Array.from({ length: 41 }, (_, i) => `u${i}`);
const resolved = resolveGiftTargets({ targetUids: many }, ME);
assert.strictEqual(resolved.length, 41);
assert.deepStrictEqual(resolved, many);

console.log("gift_targets: all assertions passed");
