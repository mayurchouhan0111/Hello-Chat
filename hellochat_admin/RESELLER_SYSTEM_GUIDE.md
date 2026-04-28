# 🛡️ Hello Chat: Reseller System Admin Guide

Welcome to the **Reseller Management System** guide. This system is designed to manage high-volume diamond distributors (Resellers) who help maintain the platform's liquidity.

---

## 🏗️ 1. Core Concepts
*   **Reseller**: A privileged user account (`isReseller: true`) authorized to purchase bulk diamond packages and sell them to end-users.
*   **USD Wallet**: Every reseller has an internal USD balance. The Admin must manually "Add Credits" (USD) to their wallet when they receive real-world payment.
*   **Diamond Packages**: Preset quantities of diamonds that resellers buy using their USD balance.

---

## 👥 2. Managing Resellers
Navigate to the **Resellers** tab in the Reseller Management screen.

### ✅ Granting Credits (USD)
1.  Locate the target reseller in the list.
2.  Click the **"Wallet"** or **"Add Credits"** icon next to their name.
3.  In the modal:
    *   **Add Credits**: Enter the amount in USD to increase their balance.
    *   **Deduct**: Enter an amount to subtract (e.g., if a payment was reversed).
4.  The reseller can now use this balance to buy diamonds.

---

## 💎 3. Diamond Package Management
Navigate to the **Packages** tab. These are the "Products" available for resellers to purchase.

### ➕ Creating a Package
1.  Click the **"Add Package"** button.
2.  Define the **Diamond Count** (e.g., 50,000 Diamonds).
3.  Define the **Price in USD** (e.g., $450.00).
4.  Save the package. It will immediately appear in the Reseller's app for purchase.

### 📝 Editing/Deleting
*   Use the **Edit** icon to adjust prices or quantities.
*   Use the **Delete** icon to remove a package from the market.

---

## 📜 4. Transaction & History Audit
Navigate to the **History** tab to track every movement in the reseller ecosystem.

*   **Wallet Adjustments**: See exactly when an admin added or removed USD from a reseller.
*   **Package Purchases**: Track which reseller bought which package and at what time.
*   **Filtering**: Use the search bar to filter by Reseller Name or Transaction ID.

---

## 💡 Best Practices for Admins
1.  **Verify Payment First**: Never add USD credits to a reseller's wallet until the real-world payment (Bank/PayPal/Crypto) is confirmed.
2.  **Monitor Balances**: Check the **Resellers** list regularly to see which resellers have high balances and which need restocking.
3.  **Audit Regularly**: Periodically review the **History** tab to ensure no unauthorized credits were added.

---

> [!IMPORTANT]
> The Reseller System uses **USD** for wallet balances and **Diamonds** for the actual assets. Always double-check the currency field before confirming a transaction.
