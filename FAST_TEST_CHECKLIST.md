# Fast Test Checklist
> Quick manual test guide — ~30 min to complete all

---

## 1. Rocket Reward Display

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Open home screen → tap a room → enter live room | Room loads without crash |
| 2 | Send enough gifts to trigger Rocket launch | Rocket animation plays |
| 3 | Tap the Rocket detail icon (i) on widget or results | Detail sheet opens |
| 4 | Check reward column values for your rocket level | Shows actual diamond amounts (not "30K / 15K / 7.5K") |
| 5 | Scroll to rank 4+ rows | No "+250 XP" text visible |
| 6 | Check frame duration badge | Shows "24h" (Level 1-4) or "72h" (Level 5) |

---

## 2. Rocket Frame — Vault & Equip

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Finish a rocket launch at Level 1-4 | Frame stored in vault with 24h expiry |
| 2 | Check warehouse/vault screen | `rocket_frame` item visible with expiry countdown |
| 3 | Tap equip on the frame | Frame equips successfully |
| 4 | Go to profile / avatar preview | Profile picture shows rocket.svga animation |
| 5 | Wait past expiry time (or set firestore `expiresAt` to past) | Frame cannot be equipped, shows "Expired" |
| 6 | Try to equip an expired frame via API | `equipItem` function rejects with "Item has expired" |

---

## 3. Room Support — Navigation

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | From home screen, tap a banner with `actionType: "room_support"` | Navigates to `/room-support` page |
| 2 | Check that "My Room" section shows current room | Room level and coins displayed |
| 3 | From live room, tap the floating "Support" button (right side, above rocket) | Navigates to `/room-support` with same roomId |
| 4 | If no active room, go to `/room-support` directly | Shows "Join a room to view Room Support" message |

---

## 4. Room Support — Partner Management

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Open Room Support page as room **owner** | "Add Partner" button visible (if slots available) |
| 2 | Tap "Add Partner" | Bottom sheet opens with user search |
| 3 | Type 2+ characters in search | Users with matching `displayName_lowercase` appear |
| 4 | Tap a user's "+" button | Loading state → sheet closes → snackbar "added as salary partner!" |
| 5 | Check Partner Slots section | Occupied count increased, new partner appears with avatar + share |
| 6 | Tap the red "X" icon on a partner row | Confirmation dialog appears |
| 7 | Tap "Remove" | Partner removed, slot freed, snackbar confirmation |
| 8 | Open Room Support page as **non-owner** (regular member) | "Add Partner" / remove buttons **not** visible |
| 9 | Try to assign a partner on Mon–Tue (any slot available) | Succeeds |
| 10 | Try to assign a partner on Wed–Sun | Function rejects with day constraint error |

---

## 5. Room Support — Target Table & Ranking

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Scroll to "Target & Reward" section | DataTable with 7 levels visible |
| 2 | Check level 7 row | Target: 50M, Slots: 7, Owner: 2.5M, Partner: 500K |
| 3 | Scroll to "Ranking" section | Top rooms listed by `totalCoins` desc |
| 4 | Check top 3 | Gold / Silver / Bronze medal styling |
| 5 | Scroll to "Last Week History" | Past 5 weeks shown with level, coins, status |

---

## 6. Room Support — Progress & Rewards

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Check "Weekly Progress" bar | Shows Level, progress %, current coins, target |
| 2 | If coins > 0, check remaining | "Remaining: X coins" shown |
| 3 | Check "Reward Distribution Info" | Owner Reward + Partner Reward shown from config |
| 4 | Verify next Wednesday date | Correct date displayed |

---

## 7. Room Support — Admin Config

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Open admin dashboard | Room Support config section visible |
| 2 | Edit a level's `coinsTarget` | Saves to Firestore `room_support_configs/settings` |
| 3 | Go back to Room Support page | Target table reflects updated values in real time |

---

## 8. Back Button Minimize Flow

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | In live room, press back | Room minimized, returns to home, floating mini player appears |
| 2 | Audio continues playing | Voice still audible |
| 3 | Tap mini player | Re-enters room |
| 4 | Press back again | App minimizes |

---

## 9. Audio Invite

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Host taps user options → "Invite to Audio Live Call" | Invitation sent |
| 2 | User receives popup | Shows accept/decline |
| 3 | User taps accept | User joins audio, seat dynamically assigned (not hardcoded seat 0) |

---

## 10. Betting (Spin Wheel)

| # | Step | Expected Behavior |
|---|------|-------------------|
| 1 | Place a bet on rocket outcome | Bet recorded |
| 2 | Rocket finishes | Results displayed with win/loss |
| 3 | Check diamond balance | Winnings credited correctly |
| 4 | Go offline → place bet → come online | Offline bet rejected by `playSpinWheel` transaction |

---

## Expected Behavior Summary

| Feature | Must Work | Must NOT Do |
|---------|-----------|-------------|
| Reward Display | Show level-specific diamond values | Show "30K / 15K / 7.5K" hardcoded |
| Rocket Frame | Store in vault with expiry, auto-equip | Equip after expiry |
| Room Support Nav | Banner + floating button → correct page | Navigate to wrong route |
| Partner Add/Remove | Owner only, Mon-Tue only, slot cap enforced | Non-owner or wrong day assign |
| Target Table | 7 levels from config | Hardcoded values |
| Weekly Cycle | Sunday lock → Wed distribute | Distribute without lock |
| Back Button | Minimize → floating player → audio continues | Close room or stop audio |
| Betting | Transaction-safe, offline rejected | Credit without balance check |
