const admin = require('firebase-admin');

// Initialize with your project ID
admin.initializeApp({
  projectId: "hellochat-e8965"
});

const db = admin.firestore();

async function seedEconomy() {
  console.log("🚀 Starting Global Economy Seeding...");

  const vipTiers = [
    { tierId: 'vip1', name: 'VIP 1', level: 1, monthlyPriceInDiamonds: 500, monthlyPriceInUSD: 5.0, benefits: ["special_frame", "badge"], profileFrame: "https://i.ibb.co/vz6G3H1/vip1-frame.png", entryAnimation: "vip_entry_1", badgeIcon: "https://i.ibb.co/3W6pZ8P/vip1-badge.png", priorityMicAccess: false, isActive: true, sortOrder: 1 },
    { tierId: 'vip2', name: 'VIP 2', level: 2, monthlyPriceInDiamonds: 1500, monthlyPriceInUSD: 15.0, benefits: ["special_frame", "badge", "entry_effect"], profileFrame: "https://i.ibb.co/tZ5Wj0K/vip2-frame.png", entryAnimation: "vip_entry_2", badgeIcon: "https://i.ibb.co/mS6Pz8P/vip2-badge.png", priorityMicAccess: false, isActive: true, sortOrder: 2 },
    { tierId: 'vip3', name: 'VIP 3', level: 3, monthlyPriceInDiamonds: 5000, monthlyPriceInUSD: 50.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic"], profileFrame: "https://i.ibb.co/pP6Z8PQ/vip3-frame.png", entryAnimation: "vip_entry_3", badgeIcon: "https://i.ibb.co/xS6Z8PQ/vip3-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 3 },
    { tierId: 'vip4', name: 'VIP 4', level: 4, monthlyPriceInDiamonds: 15000, monthlyPriceInUSD: 150.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts"], profileFrame: "https://i.ibb.co/yS6Z8PQ/vip4-frame.png", entryAnimation: "vip_entry_4", badgeIcon: "https://i.ibb.co/zS6Z8PQ/vip4-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 4 },
    { tierId: 'vip5', name: 'VIP 5', level: 5, monthlyPriceInDiamonds: 50000, monthlyPriceInUSD: 500.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "custom_id"], profileFrame: "https://i.ibb.co/AS6Z8PQ/vip5-frame.png", entryAnimation: "vip_entry_5", badgeIcon: "https://i.ibb.co/BS6Z8PQ/vip5-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 5 },
    { tierId: 'vip6', name: 'VIP 6', level: 6, monthlyPriceInDiamonds: 150000, monthlyPriceInUSD: 1500.0, benefits: ["special_frame", "badge", "entry_effect", "priority_mic", "exclusive_gifts", "manager"], profileFrame: "https://i.ibb.co/CS6Z8PQ/vip6-frame.png", entryAnimation: "vip_entry_6", badgeIcon: "https://i.ibb.co/DS6Z8PQ/vip6-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 6 },
    { tierId: 'svip', name: 'SVIP', level: 7, monthlyPriceInDiamonds: 500000, monthlyPriceInUSD: 5000.0, benefits: ["all_access", "god_badge", "world_frame"], profileFrame: "https://i.ibb.co/ES6Z8PQ/svip-frame.png", entryAnimation: "svip_entry", badgeIcon: "https://i.ibb.co/FS6Z8PQ/svip-badge.png", priorityMicAccess: true, isActive: true, sortOrder: 7 },
  ];

  const nobleTiers = [
    { tierId: 'knight', name: 'Knight', level: 1, monthlyPriceInDiamonds: 2000, benefits: ["noble_badge", "entry_sparkle"], badgeIcon: "https://i.ibb.co/3W6pZ8P/noble1.png", sortOrder: 1 },
    { tierId: 'viscount', name: 'Viscount', level: 2, monthlyPriceInDiamonds: 10000, benefits: ["noble_badge", "entry_effect", "mic_ring"], badgeIcon: "https://i.ibb.co/mS6Pz8P/noble2.png", sortOrder: 2 },
    { tierId: 'earl', name: 'Earl', level: 3, monthlyPriceInDiamonds: 30000, benefits: ["noble_badge", "entry_effect", "mic_ring", "world_shout"], badgeIcon: "https://i.ibb.co/xS6Z8PQ/noble3.png", sortOrder: 3 },
    { tierId: 'marquis', name: 'Marquis', level: 4, monthlyPriceInDiamonds: 100000, benefits: ["noble_frame", "exclusive_gifts", "kick_protection"], badgeIcon: "https://i.ibb.co/yS6Z8PQ/noble4.png", sortOrder: 4 },
    { tierId: 'duke', name: 'Duke', level: 5, monthlyPriceInDiamonds: 300000, benefits: ["castle_entry", "exclusive_gifts", "admin_immunity"], badgeIcon: "https://i.ibb.co/AS6Z8PQ/noble5.png", sortOrder: 5 },
    { tierId: 'king', name: 'King', level: 6, monthlyPriceInDiamonds: 600000, benefits: ["golden_entry", "world_announce", "custom_id"], badgeIcon: "https://i.ibb.co/BS6Z8PQ/noble6.png", sortOrder: 6 },
    { tierId: 'emperor', name: 'Emperor', level: 7, monthlyPriceInDiamonds: 1000000, benefits: ["dragon_entry", "god_badge", "full_room_ignore"], badgeIcon: "https://i.ibb.co/CS6Z8PQ/noble7.png", sortOrder: 7 },
  ];

  const batch = db.batch();

  vipTiers.forEach(v => {
    const ref = db.collection("vip_tiers").doc(v.tierId);
    batch.set(ref, { ...v, isActive: true, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });

  nobleTiers.forEach(n => {
    const ref = db.collection("noble_tiers").doc(n.tierId);
    batch.set(ref, { ...n, isActive: true, createdAt: admin.firestore.FieldValue.serverTimestamp() });
  });

  await batch.commit();
  console.log("✅ Economy Seeding Successful! All Tiers Initialized.");
}

seedEconomy().catch(console.error);
