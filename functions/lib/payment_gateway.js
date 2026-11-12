/**
 * Hello Chat - Payment Gateway Module (Revision 2)
 *
 * Implements the specifications from docs/Project Documentation.md:
 * - Single idempotent credit path: creditOrderIfPaid(orderId)
 * - Zero Client Trust: client never determines diamond count or pricing
 * - Firestore lack of unique index solved via processed_payments/{paymentId}
 * - Double-tap / retry protection via idempotencyKey
 * - Webhook deduplication via webhook_events/{eventId}
 * - Atomic execution inside db.runTransaction with agency commission and SVIP updates
 */

const admin = require("firebase-admin");
const crypto = require("crypto");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");

// Minor units: prices in paise (INR) and cents (USD)
const DEFAULT_RECHARGE_PACKAGES = [
    {
        packageId: "pack_70",
        diamonds: 70,
        bonusDiamonds: 0,
        priceINR: 9900,       // ₹99.00
        priceUSD: 120,        // $1.20
        active: true,
        sortOrder: 1,
        tag: null
    },
    {
        packageId: "pack_350",
        diamonds: 350,
        bonusDiamonds: 20,
        priceINR: 49900,      // ₹499.00
        priceUSD: 599,        // $5.99
        active: true,
        sortOrder: 2,
        tag: "HOT 🔥"
    },
    {
        packageId: "pack_700",
        diamonds: 700,
        bonusDiamonds: 50,
        priceINR: 99900,      // ₹999.00
        priceUSD: 1199,       // $11.99
        active: true,
        sortOrder: 3,
        tag: "POPULAR ⭐"
    },
    {
        packageId: "pack_1400",
        diamonds: 1400,
        bonusDiamonds: 150,
        priceINR: 199900,     // ₹1,999.00
        priceUSD: 2399,       // $23.99
        active: true,
        sortOrder: 4,
        tag: "BEST VALUE 💎"
    },
    {
        packageId: "pack_3500",
        diamonds: 3500,
        bonusDiamonds: 500,
        priceINR: 499900,     // ₹4,999.00
        priceUSD: 5999,       // $59.99
        active: true,
        sortOrder: 5,
        tag: null
    },
    {
        packageId: "pack_7000",
        diamonds: 7000,
        bonusDiamonds: 1200,
        priceINR: 999900,     // ₹9,999.00
        priceUSD: 11999,      // $119.99
        active: true,
        sortOrder: 6,
        tag: "VIP ONLY 👑"
    }
];

function getTimestampMs(ts) {
    if (!ts) return 0;
    if (typeof ts.toMillis === "function") return ts.toMillis();
    if (ts._seconds !== undefined) return ts._seconds * 1000 + Math.floor((ts._nanoseconds || 0) / 1e6);
    if (typeof ts === "number") return ts;
    const parsed = new Date(ts).getTime();
    return isNaN(parsed) ? 0 : parsed;
}

class PaymentGatewayEngine {
    constructor(db, options = {}) {
        this.db = db;
        this.applyCommissionFn = options.applyCommissionFn || null;
        this.processSvipFn = options.processSvipFn || null;
        this.processBonusFn = options.processBonusFn || null;
    }

    /**
     * Resolves the package from Firestore or fallback default catalog.
     */
    async getPackageById(packageId) {
        if (!packageId) return null;
        try {
            const doc = await this.db.collection("recharge_packages").doc(packageId).get();
            if (doc.exists) {
                const data = doc.data();
                if (data.active !== false) return { ...data, packageId: doc.id };
            }
        } catch (_) {
            // Fall back to default memory catalog
        }
        return DEFAULT_RECHARGE_PACKAGES.find(p => p.packageId === packageId) || null;
    }

    /**
     * 1. Create Payment Order (Callable backend endpoint)
     * Enforces Zero Client Trust & Idempotency.
     */
    async createOrder({ uid, packageId, gateway, idempotencyKey }) {
        if (!uid) throw new Error("Authentication required.");
        if (!packageId) throw new Error("packageId is required.");
        const cleanGateway = String(gateway || "razorpay").toLowerCase().trim();
        if (cleanGateway !== "razorpay" && cleanGateway !== "stripe") {
            throw new Error(`Unsupported gateway '${cleanGateway}'. Supported: razorpay, stripe.`);
        }

        // Scenario A1 / B3: Check if an open order already exists with this idempotencyKey
        if (idempotencyKey) {
            const existingQuery = await this.db.collection("payment_orders")
                .where("uid", "==", uid)
                .where("idempotencyKey", "==", String(idempotencyKey))
                .limit(1)
                .get();

            if (!existingQuery.empty) {
                const existingDoc = existingQuery.docs[0];
                const existingData = existingDoc.data();
                const now = Date.now();
                const expiresAtMs = getTimestampMs(existingData.expiresAt);
                // If created or pending and not expired, return same order
                if ((existingData.status === "created" || existingData.status === "pending") && expiresAtMs > now) {
                    return {
                        orderId: existingDoc.id,
                        status: existingData.status,
                        gateway: existingData.gateway,
                        amount: existingData.amount,
                        currency: existingData.currency,
                        packageSnapshot: existingData.packageSnapshot,
                        isReused: true
                    };
                }
            }
        }

        const pkg = await this.getPackageById(packageId);
        if (!pkg) throw new Error(`Recharge package '${packageId}' not found or inactive.`);

        const isINR = cleanGateway === "razorpay";
        const amountMinor = isINR ? pkg.priceINR : pkg.priceUSD;
        const currency = isINR ? "inr" : "usd";
        const orderId = `ord_${cleanGateway}_${Date.now()}_${crypto.randomBytes(4).toString("hex")}`;
        const expiresAt = Timestamp.fromMillis(Date.now() + 15 * 60 * 1000); // 15 mins expiry

        const packageSnapshot = {
            packageId: pkg.packageId,
            diamonds: pkg.diamonds,
            bonusDiamonds: pkg.bonusDiamonds || 0,
            totalDiamonds: pkg.diamonds + (pkg.bonusDiamonds || 0),
            priceMinor: amountMinor,
            currency: currency
        };

        const orderData = {
            orderId,
            uid,
            gateway: cleanGateway,
            packageSnapshot,
            amount: amountMinor,
            currency,
            status: "created",
            idempotencyKey: idempotencyKey ? String(idempotencyKey) : null,
            createdAt: FieldValue.serverTimestamp(),
            expiresAt,
            gatewayPaymentId: null,
            metadata: {
                clientVersion: "2.0.0",
                platform: "flutter"
            }
        };

        await this.db.collection("payment_orders").doc(orderId).set(orderData);

        return {
            orderId,
            status: "created",
            gateway: cleanGateway,
            amount: amountMinor,
            currency,
            packageSnapshot,
            expiresAt: expiresAt.toDate().toISOString()
        };
    }

    /**
     * 2. Shared Single Idempotent Credit Function: creditOrderIfPaid
     * This is the ONLY function that ever credits Diamonds to a user.
     * Called by both client verify call (fast path) and paymentWebhook (source of truth).
     */
    async creditOrderIfPaid(orderId, gatewayPaymentId, options = {}) {
        if (!orderId) throw new Error("orderId is required.");
        const cleanPaymentId = gatewayPaymentId ? String(gatewayPaymentId).trim() : `sim_${orderId}`;

        const orderRef = this.db.collection("payment_orders").doc(orderId);
        const processedPaymentRef = this.db.collection("processed_payments").doc(cleanPaymentId);

        // Fast-path pre-check: if already processed, stop immediately
        const alreadyProcessedSnap = await processedPaymentRef.get();
        if (alreadyProcessedSnap.exists) {
            return {
                alreadyProcessed: true,
                status: "completed",
                orderId,
                paymentId: cleanPaymentId,
                message: "Payment was already credited."
            };
        }

        // Run Single Atomic Multi-Document Transaction
        const txResult = await this.db.runTransaction(async (transaction) => {
            // 1. Transactional reads must happen before any writes
            const [orderSnap, processedSnap] = await transaction.getAll(orderRef, processedPaymentRef);
            if (!orderSnap.exists) {
                throw new Error(`Payment order '${orderId}' not found.`);
            }

            if (processedSnap.exists) {
                return { alreadyProcessed: true, status: "completed" };
            }

            const order = orderSnap.data();
            if (order.status === "completed") {
                return { alreadyProcessed: true, status: "completed" };
            }

            // Scenario D3: Verify amount and currency if provided by gateway
            if (options.amountPaidMinor !== undefined && options.amountPaidMinor !== null) {
                if (Number(options.amountPaidMinor) !== Number(order.amount)) {
                    transaction.update(orderRef, {
                        status: "flagged",
                        flagReason: `Amount mismatch: expected ${order.amount}, received ${options.amountPaidMinor}`,
                        flaggedAt: FieldValue.serverTimestamp()
                    });
                    throw new Error(`Amount tampering detected: expected ${order.amount}, got ${options.amountPaidMinor}`);
                }
            }

            if (options.currencyPaid && String(options.currencyPaid).toLowerCase() !== String(order.currency).toLowerCase()) {
                transaction.update(orderRef, {
                    status: "flagged",
                    flagReason: `Currency mismatch: expected ${order.currency}, received ${options.currencyPaid}`,
                    flaggedAt: FieldValue.serverTimestamp()
                });
                throw new Error(`Currency tampering detected: expected ${order.currency}, got ${options.currencyPaid}`);
            }

            const uid = order.uid;
            const userRef = this.db.collection("users").doc(uid);
            const userSnap = await transaction.get(userRef);
            if (!userSnap.exists) {
                throw new Error(`User '${uid}' not found.`);
            }

            const userData = userSnap.data();
            const totalDiamonds = order.packageSnapshot.totalDiamonds || (order.packageSnapshot.diamonds + (order.packageSnapshot.bonusDiamonds || 0));
            // Calculate approximate USD amount for agency commission and SVIP tracking
            const usdAmount = order.currency === "usd"
                ? (order.amount / 100)
                : Number((order.amount / 100 / 85.0).toFixed(2)); // Approx INR to USD conversion

            // 2. Perform All Atomic Mutations
            // A. Update User Balances
            transaction.update(userRef, {
                diamondBalance: FieldValue.increment(totalDiamonds),
                monthlyRecharge: FieldValue.increment(totalDiamonds),
                totalRechargeGenerated: FieldValue.increment(usdAmount)
            });

            // B. Apply Agency Commission inside transaction
            if (this.applyCommissionFn) {
                try {
                    await this.applyCommissionFn(transaction, uid, usdAmount, `pay_${orderId}`, {}, userSnap);
                } catch (commErr) {
                    console.error("[PAYMENT_COMMISSION_WARN] Agency commission calculation skipped:", commErr);
                }
            }

            // C. Apply SVIP Points
            if (this.processSvipFn) {
                try {
                    this.processSvipFn(transaction, userRef, userData, usdAmount);
                } catch (svipErr) {
                    console.error("[PAYMENT_SVIP_WARN] SVIP point calculation skipped:", svipErr);
                }
            }

            // D. Lock Processed Payment Document (Idempotency Key)
            transaction.set(processedPaymentRef, {
                paymentId: cleanPaymentId,
                orderId,
                uid,
                amount: order.amount,
                currency: order.currency,
                diamondsCredited: totalDiamonds,
                creditedAt: FieldValue.serverTimestamp(),
                source: options.isWebhook ? "webhook" : "client_fast_path"
            });

            // E. Flip Order Status to completed
            transaction.update(orderRef, {
                status: "completed",
                gatewayPaymentId: cleanPaymentId,
                completedAt: FieldValue.serverTimestamp()
            });

            // F. Create User Passbook Ledger Entry (transactions)
            const txDocRef = userRef.collection("transactions").doc();
            transaction.set(txDocRef, {
                type: "RECHARGE",
                amount: totalDiamonds,
                orderId,
                gateway: order.gateway,
                gatewayPaymentId: cleanPaymentId,
                priceMinor: order.amount,
                currency: order.currency,
                packageId: order.packageSnapshot.packageId,
                timestamp: FieldValue.serverTimestamp()
            });

            // G. Write Global Audit Log
            const auditRef = this.db.collection("audit_logs").doc();
            transaction.set(auditRef, {
                actorUid: uid,
                action: "PAYMENT_CREDIT",
                targetId: orderId,
                details: {
                    gateway: order.gateway,
                    gatewayPaymentId: cleanPaymentId,
                    diamondsCredited: totalDiamonds,
                    amount: order.amount,
                    currency: order.currency
                },
                timestamp: FieldValue.serverTimestamp()
            });

            return {
                alreadyProcessed: false,
                status: "completed",
                orderId,
                paymentId: cleanPaymentId,
                diamondsCredited: totalDiamonds,
                uid
            };
        });

        // 3. Best-effort inline event bonuses outside transaction (do not fail the recharge)
        if (this.processBonusFn && !txResult.alreadyProcessed) {
            try {
                await this.processBonusFn(txResult.uid, txResult.diamondsCredited);
            } catch (bonusErr) {
                console.error("[PAYMENT_EVENT_BONUS_WARN]:", bonusErr);
            }
        }

        return txResult;
    }

    /**
     * 3. Verify HMAC Signature on Raw Webhook Body
     */
    verifyWebhookSignature(rawBody, signature, secret) {
        if (!rawBody || !signature || !secret) return false;
        try {
            const expectedSignature = crypto
                .createHmac("sha256", secret)
                .update(rawBody)
                .digest("hex");
            return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature));
        } catch (_) {
            return false;
        }
    }

    /**
     * 4. Handle Gateway Webhooks
     * Deduplicates by eventId and routes to creditOrderIfPaid or refund handler.
     */
    async handleWebhook({ eventId, eventType, rawBody, signature, secret, payload, gateway }) {
        if (!eventId) throw new Error("Missing eventId.");
        
        // Scenario C3: Verify signature if secret configured
        if (secret && !this.verifyWebhookSignature(rawBody, signature, secret)) {
            const err = new Error("Invalid webhook signature.");
            err.statusCode = 401;
            throw err;
        }

        const eventRef = this.db.collection("webhook_events").doc(eventId);
        const eventSnap = await eventRef.get();
        if (eventSnap.exists) {
            return { duplicate: true, eventId, status: "ignored" };
        }

        let result = { processed: false };

        // Route by Gateway Event Type
        if (gateway === "razorpay" && eventType === "payment.captured") {
            const payment = payload.payload?.payment?.entity;
            const orderId = payment?.notes?.orderId || payment?.order_id;
            const paymentId = payment?.id;
            if (orderId && paymentId) {
                result = await this.creditOrderIfPaid(orderId, paymentId, {
                    isWebhook: true,
                    amountPaidMinor: payment.amount,
                    currencyPaid: payment.currency
                });
            }
        } else if (gateway === "stripe" && eventType === "payment_intent.succeeded") {
            const pi = payload.data?.object;
            const orderId = pi?.metadata?.orderId;
            const paymentId = pi?.id;
            if (orderId && paymentId) {
                result = await this.creditOrderIfPaid(orderId, paymentId, {
                    isWebhook: true,
                    amountPaidMinor: pi.amount_received,
                    currencyPaid: pi.currency
                });
            }
        }

        // Record processed webhook event for audit trail
        await eventRef.set({
            eventId,
            gateway,
            eventType,
            receivedAt: FieldValue.serverTimestamp(),
            result
        });

        return { duplicate: false, eventId, result };
    }
}

module.exports = {
    DEFAULT_RECHARGE_PACKAGES,
    PaymentGatewayEngine
};
