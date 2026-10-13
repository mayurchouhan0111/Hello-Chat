/**
 * Emulator-only seed. Run with FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST set.
 * node seed_emulator.js
 */
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8085";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";
process.env.GCLOUD_PROJECT = "hellochat-e8965";

const admin = require("firebase-admin");
admin.initializeApp({ projectId: "hellochat-e8965" });
const db = admin.firestore();
const auth = admin.auth();
const T = admin.firestore.FieldValue.serverTimestamp();

const PHONE = {
  owner: "+919000000001",
  superadmin: "+919000000002",
  admin: "+919000000003",
  agency: "+919000000004",
  host: "+919000000005",
  host2: "+919000000006",
};

async function ensureUser(uid, phone, data) {
  try { await auth.getUser(uid); } catch (e) {
    await auth.createUser({ uid, phoneNumber: phone, displayName: data.displayName || uid });
  }
  await db.collection("users").doc(uid).set({
    // Same ordering/filter keys every users query sorts or filters on.
    createdAt: T, timestamp: T, updatedAt: T,
    sortOrder: 1, order: 1, period: "daily",
    isActive: true, isReseller: false, isBanned: false,
    username: "u" + uid, helloId: "HL" + uid,
    ...data, uid, updatedAt: T,
  }, { merge: true });
}

async function seed() {
  const OWNER = "ownerT1", SA = "saT1", ADM = "admT1", AGY = "agyT1", HST = "hstT1", HST2 = "hstT2";
  const BR = "branchT1";

  await ensureUser(OWNER, PHONE.owner, {
    displayName: "Test Owner", role: "owner", tags: ["Owner"], branchId: null,
    usdCommissionBalance: 1250.75, beans: 999999, diamonds: 100000, verificationStatus: "verified",
    kycStatus: "approved", status: "active",
  });
  await ensureUser(SA, PHONE.superadmin, {
    displayName: "Test SuperAdmin", role: "superadmin", tags: ["SuperAdmin"], branchId: BR,
    superAdminId: SA, usdCommissionBalance: 400, beans: 50000, diamonds: 20000,
    verificationStatus: "verified", kycStatus: "approved", status: "active",
  });
  await ensureUser(ADM, PHONE.admin, {
    displayName: "Test Admin", role: "admin", tags: ["Admin"], branchId: BR,
    superAdminId: SA, adminId: ADM, usdCommissionBalance: 220.5, beans: 21000, diamonds: 9000,
    verificationStatus: "verified", kycStatus: "approved", status: "active",
  });
  await ensureUser(AGY, PHONE.agency, {
    displayName: "Test Agency", role: "agency", tags: ["Agency"], branchId: BR,
    superAdminId: SA, adminId: ADM, agencyId: AGY, isAgencyOwner: true,
    usdCommissionBalance: 88.25, beans: 12000, diamonds: 5000,
    verificationStatus: "verified", kycStatus: "approved", status: "active",
  });
  await ensureUser(HST, PHONE.host, {
    displayName: "Test Host", role: "host", tags: [], branchId: BR,
    superAdminId: SA, adminId: ADM, agencyId: AGY, usdCommissionBalance: 15.5,
    beans: 115461056, diamonds: 1200, verificationStatus: "verified", kycStatus: "pending",
    status: "active", salaryStatus: "active",
  });
  await ensureUser(HST2, PHONE.host2, {
    displayName: "Test Host 2", role: "host", tags: [], branchId: BR,
    superAdminId: SA, adminId: ADM, agencyId: AGY, usdCommissionBalance: 4.5,
    beans: 800, diamonds: 60, verificationStatus: "pending", kycStatus: "none", status: "active",
  });

  await db.collection("branches").doc(BR).set({
    id: BR, name: "Test Branch", superAdminUid: SA, status: "active", createdBy: OWNER, createdAt: T,
  }, { merge: true });

  // Host Metrics roster reads host_metrics + salaryStatus, not users.
  const day = "2026-09-2" + "7";
  const hostMeta = { [day]: 145, ["2026-09-26"]: 92 };
  for (const [uid, mins, days] of [[HST, 3480, hostMeta], [HST2, 610, { [day]: 610 }]]) {
    await db.collection("host_metrics").doc(uid).set({
      uid, displayName: uid === HST ? "Test Host" : "Test Host 2",
      liveMinutesTotal: mins, liveSessionsTotal: uid === HST ? 14 : 5,
      liveMinutesByDay: days, lastSessionEndedAt: T, photoUrl: null,
    }, { merge: true });
    await db.collection("salaryStatus").doc(uid).set({
      uid, totalBeansEarned: uid === HST ? 115461056 : 800,
      completedLevels: { 1: T, 2: T, 3: T }, lastPayoutAt: T,
    }, { merge: true });
  }
  // User fields the host row and dashboards read.
  for (const [uid, target, recharge] of [[HST, 200000000, 420], [HST2, 500000, 15]]) {
    await db.collection("users").doc(uid).set({
      monthlyTargetBeans: target, totalRechargeGenerated: recharge, beansBalance: uid === HST ? 115461056 : 800,
    }, { merge: true });
  }

  // Firestore's orderBy() silently drops docs that lack the field, so every doc
  // carries the full set of ordering/filter keys any screen might sort on.
  const DEF = (id) => ({
    createdAt: T, timestamp: T, updatedAt: T, startedAt: T,
    sortOrder: 1, order: 1, level: 1, period: "daily",
    priceInDiamonds: 100, points: 10, action: "seed",
    isActive: true, isReseller: false, isBanned: false,
    verificationStatus: "verified",
    name: "Item " + id, title: "Item " + id,
    username: "u" + id, helloId: "HL" + id,
  });
  const set = (coll, id, data) =>
    db.collection(coll).doc(id).set({ ...DEF(id), ...data, createdAt: T, updatedAt: T }, { merge: true });
  const add = (coll, data) => {
    const id = db.collection(coll).doc().id;
    return db.collection(coll).doc(id).set({ ...DEF(id), ...data, id, createdAt: T, updatedAt: T }, { merge: true });
  };

  for (let i = 1; i <= 6; i++) {
    await set("rooms", "roomT" + i, {
      id: "roomT" + i, name: "Lounge " + i, title: "Lounge " + i, roomId: "roomT" + i,
      currentUsersCount: 120 - i * 7, viewers: 120 - i * 7, pkActive: i % 2 === 0,
      ownerUid: i % 2 ? HST : HST2, isActive: true, status: "live", language: "en",
      createdAt: T,
    });
  }
  for (let i = 1; i <= 5; i++) {
    await set("reports", "repT" + i, {
      id: "repT" + i, reason: ["Hate Speech", "Nudity / Inappropriate", "Harassment", "Fake Account", "Spam"][i - 1],
      type: "user", reporterUid: HST2, targetUid: HST, roomId: "roomT1",
      description: "Seeded report " + i, status: i < 4 ? "pending" : "resolved", severity: "high",
      timestamp: T, reportedAt: T,
    });
  }
  for (let i = 1; i <= 5; i++) {
    await set("recharges", "rchT" + i, {
      id: "rchT" + i, orderId: "ORD-T" + i, uid: i % 2 ? HST : AGY, amount: i * 10,
      currency: "USD", usdAmount: i * 10, diamonds: i * 10000, status: i < 4 ? "approved" : "pending",
      method: "upi", verified: i < 4, gateway: "stripe", timestamp: T,
    });
  }
  for (let i = 1; i <= 5; i++) {
    await set("withdrawals", "wdT" + i, {
      id: "wdT" + i, uid: i % 2 ? AGY : ADM, amount: i * 25, currency: "USD",
      method: "bank", status: i < 3 ? "pending" : i < 5 ? "approved" : "rejected",
      account: "XXXX44" + i, timestamp: T, reviewedAt: T,
    });
  }
  for (let i = 1; i <= 4; i++) {
    await set("resellers", "resT" + i, {
      id: "resT" + i, uid: "resellerT" + i, name: "Reseller " + i, diamonds: 5000 * i,
      balance: 120.5 * i, usdBalance: 120.5 * i, status: "active", rate: 0.7,
      isReseller: true, timestamp: T,
    });
  }
  for (let i = 1; i <= 5; i++) {
    await set("commission_withdrawals", "cwdT" + i, {
      id: "cwdT" + i, uid: i % 2 ? AGY : ADM, amount: i * 40, currency: "USD",
      status: i < 3 ? "pending" : i < 5 ? "approved" : "rejected", method: "bank", timestamp: T,
    });
  }
  for (let i = 1; i <= 8; i++) {
    await set("gifts", "giftT" + i, {
      id: "giftT" + i, name: "Gift " + i, title: "Gift " + i, diamonds: i * 100, price: i * 100,
      icon: "🎁", image: "", level: i, type: "normal", enabled: true, status: "active", sortOrder: i,
    });
    await set("vip_tiers", "vipT" + i, {
      id: "vipT" + i, name: "VIP " + i, title: "VIP " + i, level: i, price: i * 4.99,
      benefits: ["Badge", "Exclusive gifts"], color: "#f59e0b", enabled: true, status: "active",
    });
    await set("svip_levels", "svipT" + i, {
      id: "svipT" + i, name: "SVIP " + i, title: "SVIP " + i, level: i, price: i * 19.99,
      benefits: ["Frame", "Emotes"], color: "#a855f7", enabled: true, status: "active",
    });
    await set("prestige_items", "prstT" + i, {
      id: "prstT" + i, name: "Prestige " + i, title: "Prestige " + i, level: i,
      diamonds: i * 500, enabled: true, status: "active",
    });
    await set("noble_tiers", "nblT" + i, {
      id: "nblT" + i, name: "Noble " + i, level: i, diamonds: i * 300, enabled: true, status: "active",
    });
  }
  for (let i = 1; i <= 6; i++) {
    await add("moments", {
      id: "momentT" + i, content: "Seeded moment " + i, text: "Seeded moment " + i,
      // MomentsManagement filters on caption / userId - without them the
      // empty-search filter matches nothing and the list renders blank.
      caption: "Seeded moment " + i, userId: HST,
      uid: HST, author: "Test Host", likes: i * 11, comments: i, status: "published",
      visibility: "public", image: "", timestamp: T,
    });
    await add("gift_events", {
      id: "geT" + i, name: "Gift Event " + i, title: "Gift Event " + i,
      status: i < 4 ? "active" : "draft", startsAt: T, endsAt: T, reward: i * 1000,
      enabled: true,
    });
    await add("families", {
      id: "famT" + i, name: "Family " + i, title: "Family " + i, leaderUid: HST,
      level: i, points: i * 500, members: [HST, HST2], memberCount: 2,
      status: "active", createdAt: T,
    });
  }
  await set("gift_events", "geMain", {
    id: "geMain", name: "Mega Gift Rush", title: "Mega Gift Rush", status: "active",
    startsAt: T, endsAt: T, reward: 50000, enabled: true,
  });
  for (let i = 1; i <= 4; i++) {
    await set("gifts", "geGift" + i, { id: "geGift" + i, name: "Event Gift " + i, diamonds: i * 99, enabled: true, status: "active" });
  }
  await set("recharge_bonus_events", "rbeT1", {
    id: "rbeT1", name: "Recharge Bonus Week", title: "Recharge Bonus Week",
    status: "active", startsAt: T, endsAt: T, bonusPercent: 20, enabled: true,
  });
  for (let i = 1; i <= 4; i++) {
    await set("recharge_bonus_packages", "rbpT" + i, {
      id: "rbpT" + i, name: "Pack " + i, title: "Pack " + i, amount: i * 5, bonus: i * 500,
      diamonds: i * 1000, enabled: true, status: "active", sortOrder: i,
    });
  }
  for (let i = 1; i <= 5; i++) {
    await set("relationship_levels", "rlT" + i, {
      id: "rlT" + i, level: i, name: "Level " + i, title: "Level " + i,
      requiredPoints: i * 100, rewards: ["Heart"], enabled: true, status: "active",
    });
    await set("relationship_rewards", "rrT" + i, {
      id: "rrT" + i, name: "Reward " + i, level: i, diamonds: i * 50, enabled: true, status: "active",
    });
  }
  await add("relationship_requests", {
    id: "reqT1", fromUid: HST, toUid: HST2, fromName: "Test Host", toName: "Test Host 2",
    status: "pending", points: 10, timestamp: T,
  });
  await set("family_battle_configs", "fbcT1", {
    id: "fbcT1", enabled: true, status: "active", tapLimit: 100, rewardPool: 50000,
    durationMinutes: 60, name: "Family Battle", title: "Family Battle",
  });
  await set("room_support_configs", "rscT1", {
    id: "rscT1", enabled: true, status: "active", name: "Support Config",
    title: "Support Config", banners: [], maxReports: 20,
  });
  await set("room_integrated_banners", "ribT1", {
    id: "ribT1", name: "Banner 1", title: "Banner 1", imageUrl: "", link: "",
    enabled: true, status: "active", sortOrder: 1,
  });
  await set("app_banners", "abT1", {
    id: "abT1", name: "Home Banner", title: "Home Banner", imageUrl: "", link: "",
    enabled: true, status: "active", sortOrder: 1,
  });
  await set("global_announcements", "gaT1", {
    id: "gaT1", message: "Seeded announcement", title: "Seeded announcement",
    enabled: true, status: "active", priority: 1,
  });
  for (let i = 1; i <= 3; i++) {
    await set("games_meta", "gmT" + i, {
      id: "gmT" + i, name: "Mini Game " + i, title: "Mini Game " + i, type: "luck",
      enabled: true, status: "active", entryFee: i * 10, prize: i * 100,
    });
    await set("svip_banners", "svbT" + i, {
      id: "svbT" + i, name: "SVIP Banner " + i, title: "SVIP Banner " + i,
      enabled: true, status: "active", imageUrl: "",
    });
    await set("custom_gift_requests", "cgrT" + i, {
      id: "cgrT" + i, name: "Custom Gift " + i, uid: HST, status: "pending",
      amount: i * 500, description: "Seeded request", timestamp: T,
    });
  }
  await set("game_settings", "rocket", {
    id: "rocket", enabled: true, status: "active", name: "Rocket",
    fuelCost: 10, multiplier: 2.5, maxWin: 100000, title: "Rocket",
  });
  await set("game_settings", "winning", {
    id: "winning", enabled: true, status: "active", name: "Winning Config",
    winRate: 0.35, jackpotChance: 0.02, title: "Winning Config",
  });
  await set("app_config", "main", {
    id: "main", appName: "Hello Chat", maintenanceMode: false, registrationOpen: true,
    requireVerifiedRecharge: true, supportedGateways: ["stripe", "upi", "paypal"],
    usdToDiamondRate: 1000000, title: "Main Config",
  });
  await set("system_settings", "main", {
    id: "main", maintenanceMode: false, appName: "Hello Chat",
    supportedGateways: ["stripe", "upi", "paypal"], usdToDiamondRate: 1000000,
  });
  await set("system_configs", "main", { id: "main", key: "main", value: "{}", enabled: true });
  await db.collection("admin_logs").add({
    id: "logT1", actorUid: OWNER, actorRole: "owner", action: "seed",
    details: "Seeded emulator data", timestamp: T, ip: "127.0.0.1",
  });
  await set("svip_audit_logs", "svlogT1", {
    id: "svlogT1", action: "upgrade", actorUid: OWNER, targetUid: HST, timestamp: T,
  });
  await add("lucky_gift_transactions", {
    id: "lgtT1", uid: HST, giftId: "giftT1", diamonds: 100, multiplier: 2, timestamp: T,
  });
  await set("familyJoinRequests", "fjrT1", {
    id: "fjrT1", familyId: "famT1", uid: HST2, status: "pending", timestamp: T,
  });
  await set("familyBattleRequests", "fbrT1", {
    id: "fbrT1", familyId: "famT1", challengerUid: HST, status: "pending", timestamp: T,
  });

  const cols = await db.listCollections();
  console.log("SEEDED OK");
  console.log("collections now:", cols.length);
  console.log("LOGINS:", JSON.stringify(PHONE, null, 2));
  process.exit(0);
}

seed().catch((e) => { console.error("SEED FAILED", e); process.exit(1); });
