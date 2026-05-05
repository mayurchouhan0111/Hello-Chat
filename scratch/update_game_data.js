/* 
  Recommended Firestore Data for 'game_settings/lucky_spin'
  
  Copy and paste the 'segments' array below into your Firebase Console:
*/

const segments = [
    { "name": "hotdog", "multiplier": 10, "emoji": "🌭", "weight": 5, "category": "standard" },
    { "name": "skewer", "multiplier": 5, "emoji": "🍢", "weight": 10, "category": "standard" },
    { "name": "meat", "multiplier": 25, "emoji": "🥩", "weight": 3, "category": "standard" },
    { "name": "pizza", "multiplier": 45, "emoji": "🍕", "weight": 1, "category": "pizza" },
    { "name": "carrot", "multiplier": 5, "emoji": "🥕", "weight": 20, "category": "standard" },
    { "name": "corn", "multiplier": 5, "emoji": "🌽", "weight": 20, "category": "standard" },
    { "name": "salad", "multiplier": 5, "emoji": "🥗", "weight": 10, "category": "salad" },
    { "name": "tomato", "multiplier": 5, "emoji": "🍅", "weight": 20, "category": "standard" }
];

console.log("--- START OF JSON ---");
console.log(JSON.stringify({ segments }, null, 2));
console.log("--- END OF JSON ---");

console.log("\nINSTRUCTIONS:");
console.log("1. Open Firebase Console -> Firestore -> game_settings -> lucky_spin");
console.log("2. Edit the 'segments' field and paste the array from above.");
