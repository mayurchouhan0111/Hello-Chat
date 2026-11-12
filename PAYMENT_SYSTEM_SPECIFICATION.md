# Hello Chat — Payment & Recharge System Specification

**Document Version:** 1.0  
**Date:** November 2026  
**Status:** Architecture & Production Implementation Specification  

---

## 1. Executive Summary

The **Hello Chat Payment & Recharge System** provides a bank-grade, secure, multi-currency financial infrastructure for digital currency (Diamonds/Coins) recharge, real-time in-app gifting, and multi-tier agency commission distribution.

The system is architected around **Zero Client Trust**, ensuring that every financial transaction, balance mutation, and commission calculation is executed via server-side atomic transactions with cryptographic signature verification.

---

## 2. Supported Payment Gateways & Currencies

| Gateway | Supported Regions | Currencies | Methods |
| :--- | :--- | :--- | :--- |
| **Razorpay** | India & South Asia | INR (₹) | UPI (GPay, PhonePe, Paytm), NetBanking, Debit/Credit Cards |
| **Stripe** | Global / International | USD ($), EUR (€), GBP (£), etc. | Credit/Debit Cards, Apple Pay, Google Pay |
| **Official Agency Top-Up** | Authorized Resellers | Local Currencies / Fiat Transfer | Controlled Admin & Reseller Portal with OTP verification |

---

## 3. End-to-End Payment Flow & Architecture

```
[Flutter Mobile Client]
         │  1. Request Order (Tier / Diamonds)
         ▼
[Firebase Cloud Function] ──► [Payment Gateway API (Stripe / Razorpay)]
         │                              │
         │  2. Order Created & Signed   │
         ◄──────────────────────────────┘
         │
         ▼  3. Launch Native Checkout SDK (UPI / Card)
[User Completes Payment]
         │
         ▼  4. Client receives Gateway Signature / Token
[Client Verification Request]
         │
         ▼
[Server-Side Atomic Cloud Function (verifyPaymentAndCredit)]
   ├── 5. Cryptographic HMAC Signature Verification
   ├── 6. Duplicate Transaction Check (Idempotency Key)
   ├── 7. Atomic Firestore Transaction (RunTransaction):
   │        ├── Credit User Diamond Balance
   │        ├── Create Immutable Transaction Ledger Entry
   │        └── Calculate & Disburse Agency Referral Commission
   └── 8. Return Success & Broadcast Real-Time Balance Update
```

---

## 4. Key Security & Compliance Mechanisms

1. **Server-Side Verification (Zero Client Trust):**
   - The mobile client *never* modifies diamond or cash balances directly.
   - Balances are strictly updated inside Cloud Functions using Firebase Admin SDK with `db.runTransaction()`.
2. **Anti-Replay & Idempotency Protection:**
   - Every transaction ID from Razorpay (`razorpay_payment_id`) and Stripe (`payment_intent_id`) is indexed with unique constraints.
   - Replay attacks or duplicate webhook triggers are rejected automatically without duplicate credits.
3. **Cryptographic Signature Verification:**
   - Razorpay: Verified using `HMAC_SHA256(order_id + "|" + payment_id, secret)`.
   - Stripe: Verified using Stripe Webhook Signature (`stripe-signature`).
4. **Audit Trail & Immutable Ledger:**
   - Every transaction logs:
     - `transactionId`
     - `userId`
     - `amount` & `currency`
     - `diamondsCredited`
     - `paymentProvider`
     - `status` (`completed`, `refunded`, `flagged`)
     - `timestamp` (Server-side timestamp)

---

## 5. Recharge Commission & Agency Wallet System

The system integrates an automated multi-tier agency commission distribution engine:

1. **Agency Reseller Discounts:** Authorized agents purchase bulk diamonds at tiered partner rates to distribute to users.
2. **Automatic Referral Commission:** When a user recharges, if linked to an agency/host, the configured percentage commission (e.g., 5% to 15%) is instantly calculated and deposited into the agency’s **Commission Wallet**.
3. **Withdrawal Request Flow:**
   - Agencies can submit withdrawal requests from their portal.
   - Admin reviews, verifies bank/UPI details, and approves or rejects with audit logs.

---

## 6. Implementation Checklist & Client Requirements

To switch from staging/test mode to live production, the client needs to provide:

- [ ] **Razorpay Live API Credentials:**
  - `Key ID`
  - `Key Secret`
  - Webhook Secret
- [ ] **Stripe Live API Credentials:**
  - `Publishable Key`
  - `Secret Key`
  - Webhook Signing Secret
- [ ] **Official Company Account / Bank Details:** For direct merchant payouts.

---

*Hello Chat Technical Team*

