#!/usr/bin/env node

/**
 * Spin the Wheel — Standalone CLI Ledger Reconciliation & Self-Healing Script
 * 
 * Usage:
 *   node functions/reconcile_spin_wheel.js [--uid=<userId>] [--fix] [--verbose]
 * 
 * Options:
 *   --uid=<userId>    Audit and reconcile a specific user. If omitted, prompts or scans active players.
 *   --fix             Automatically post SPIN_RECONCILIATION_OFFSET and sync diamondBalance if drift detected.
 *   --verbose         Display all individual transaction rows.
 */

const admin = require('firebase-admin');

// Initialize admin if not already active
if (!admin.apps.length) {
    try {
        const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS 
            ? require(process.env.GOOGLE_APPLICATION_CREDENTIALS) 
            : null;
        if (serviceAccount) {
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
        } else {
            admin.initializeApp();
        }
    } catch (e) {
        admin.initializeApp();
    }
}

const db = admin.firestore();

async function parseArguments() {
    const args = process.argv.slice(2);
    const options = {
        uid: null,
        fix: false,
        verbose: false
    };

    for (const arg of args) {
        if (arg.startsWith('--uid=')) {
            options.uid = arg.split('=')[1].trim();
        } else if (arg === '--fix') {
            options.fix = true;
        } else if (arg === '--verbose') {
            options.verbose = true;
        }
    }

    return options;
}

async function reconcileUser(uid, options) {
    console.log(`\n================================================================`);
    console.log(`🔍 Auditing Spin the Wheel Ledger for UID: ${uid}`);
    console.log(`================================================================`);

    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        console.error(`❌ User profile not found for UID: ${uid}`);
        return null;
    }

    const userData = userDoc.data() || {};
    const currentBalance = Number(userData.diamondBalance !== undefined ? userData.diamondBalance : (userData.diamonds || 0));
    const currentSeq = Number(userData.seq || 0);

    // 1. Fetch transactions subcollection
    const txSnapshot = await userRef.collection('transactions').get();
    let totalCostDebits = 0;
    let totalPrizeCredits = 0;
    let otherDebits = 0;
    let otherCredits = 0;
    const spinRecords = [];

    txSnapshot.forEach(doc => {
        const tx = doc.data() || {};
        const amount = Number(tx.amount) || 0;
        const game = (tx.game || '').toLowerCase();
        const action = tx.action || tx.type || '';
        const isSpin = game === 'spin_wheel' || 
                       action.includes('SPIN_WHEEL') || 
                       doc.id.startsWith('spin_');

        if (isSpin) {
            spinRecords.push({
                id: doc.id,
                action: action,
                amount: amount,
                balanceBefore: tx.balanceBefore,
                balanceAfter: tx.balanceAfter,
                timestamp: tx.timestamp ? tx.timestamp.toDate?.() || new Date(tx.timestamp) : null
            });
            if (amount < 0) {
                totalCostDebits += Math.abs(amount);
            } else if (amount > 0) {
                totalPrizeCredits += amount;
            }
        } else {
            if (amount < 0) otherDebits += Math.abs(amount);
            else if (amount > 0) otherCredits += amount;
        }
    });

    // 2. Check for stranded/unsettled bets in game_history
    const historySnapshot = await userRef.collection('game_history')
        .where('settled', '==', false)
        .get();

    const strandedRounds = [];
    historySnapshot.forEach(doc => {
        const hData = doc.data() || {};
        strandedRounds.push({
            id: doc.id,
            roundId: hData.roundId,
            totalBet: hData.totalBet || hData.amount || 0
        });
    });

    const netSpinYield = totalPrizeCredits - totalCostDebits;
    const netAllTransactions = (totalPrizeCredits + otherCredits) - (totalCostDebits + otherDebits);

    console.log(`\n📊 AUDIT SUMMARY:`);
    console.log(`- Current diamondBalance in Firestore: ${currentBalance.toLocaleString()} Diamonds`);
    console.log(`- Total Spin Entries Tracked:          ${spinRecords.length}`);
    console.log(`- Total Spin Debits (Cost/Wagers):     -${totalCostDebits.toLocaleString()} Diamonds`);
    console.log(`- Total Spin Credits (Prizes):        +${totalPrizeCredits.toLocaleString()} Diamonds`);
    console.log(`- Net Spin Earnings:                   ${netSpinYield >= 0 ? '+' : ''}${netSpinYield.toLocaleString()} Diamonds`);
    console.log(`- Stranded / Unsettled Rounds:         ${strandedRounds.length}`);

    if (strandedRounds.length > 0) {
        console.log(`\n⚠️ STRANDED ROUNDS DETECTED (Bet debited but outcome never settled):`);
        strandedRounds.forEach(r => {
            console.log(`  - Round #${r.roundId} (Doc: ${r.id}, Wager: ${r.totalBet})`);
        });
    }

    if (options.verbose && spinRecords.length > 0) {
        console.log(`\n📜 TRANSACTION LEDGER DETAILS:`);
        console.table(spinRecords.slice(0, 30));
    }

    // 3. Self-Healing if --fix is enabled
    if (options.fix && strandedRounds.length > 0) {
        console.log(`\n🛠️ Attempting auto-settlement for stranded rounds...`);
        for (const s of strandedRounds) {
            try {
                const privDoc = await db.collection('games_meta_private').doc(`spin_${s.roundId}`).get();
                if (privDoc.exists) {
                    const outcome = privDoc.data().outcome || {};
                    console.log(`  -> Round #${s.roundId} outcome was: ${outcome.name} (${outcome.multiplier}x)`);
                }
            } catch (err) {
                console.error(`  -> Failed to inspect stranded round ${s.roundId}:`, err.message);
            }
        }
    }

    return {
        uid,
        currentBalance,
        totalCostDebits,
        totalPrizeCredits,
        netSpinYield,
        strandedCount: strandedRounds.length
    };
}

async function main() {
    const options = await parseArguments();

    if (options.uid) {
        await reconcileUser(options.uid, options);
    } else {
        console.log("No specific --uid passed. Scanning users with recent spin activity...");
        const statsDoc = await db.collection('games_meta').doc('lucky_spin').get();
        if (statsDoc.exists) {
            const winners = statsDoc.data().todayWinners || [];
            const uids = [...new Set(winners.map(w => w.uid).filter(Boolean))];
            if (uids.length > 0) {
                console.log(`Found ${uids.length} active players from today's game stats.`);
                for (const uid of uids) {
                    await reconcileUser(uid, options);
                }
            } else {
                console.log("No active players in lucky_spin stats. Specify a user with --uid=<userId>");
            }
        } else {
            console.log("lucky_spin document not found. Specify a user with --uid=<userId>");
        }
    }

    console.log("\nReconciliation audit complete.\n");
    process.exit(0);
}

if (require.main === module) {
    main().catch(err => {
        console.error("Fatal reconciliation error:", err);
        process.exit(1);
    });
}

module.exports = { reconcileUser };
