# Spec: Family Battle / Clan System Fix

## Objective
Fix all identified issues in the Family Battle / Clan system per the 10-task prompt. This includes fixing the Join Requests screen layout, removing unrequested features, removing the Convert Diamonds section, implementing proper contribution tracking, fixing ranking, level system, color system, and progress bars.

## Tech Stack
- Flutter (Dart) frontend with Riverpod state management
- Firebase Firestore (database)
- Firebase Cloud Functions (Node.js)

## Commands
- Build: `flutter build`
- Test: `flutter test`
- Lint: `flutter analyze`
- Dev: `flutter run`

## Project Structure (relevant files)
```
lib/
  core/
    models/
      family_model.dart           → Family data model (level, rank, thresholds)
      family_member_model.dart    → Member data model (contribution, XP, combat points)
      family_join_request_model.dart → Join request model
    services/
      family_service.dart         → Firestore CRUD, battle logic, contribution, conversion
    providers/
      family_provider.dart        → Riverpod stream/future providers
    widgets/
      family_badge_widget.dart    → Badge display (needs level color)
      family_progress_bar.dart    → Progress bar (needs level color)
    constants/
      app_colors.dart             → Color constants (needs family level colors)
  features/
    profile/presentation/screens/family/
      join_requests_screen.dart   → TASK 1: Fix request cards
      family_portal_screen.dart   → TASKS 2, 3, 4-6, 8, 10: Dashboard
      family_list_screen.dart     → TASK 7: Ranking
```

## Tasks

### Task 1: Join Requests Screen
- Add User ID display below username
- Ensure Accept and Reject buttons both work
- Test: 1 request, multiple requests, empty list, different screen sizes

### Task 2: Remove Unrequested Features
- Remove "Treasury" and "Wardrobe" menu items from dashboard
- Remove any other unrequested buttons/cards

### Task 3: Remove Convert Diamonds Section
- Remove `_buildConvertSection()` and `_showConvertDialog()` methods
- Remove associated UI, logic, and any blank spaces

### Tasks 4-6: Contribution System
- Add `totalDiamondsSent` and `totalBattlePoints` fields to FamilyMemberModel
- Modify `convertDiamondsToPoints` to also update member contribution
- Create a contribution history subcollection or array
- Store per-member: totalDiamondsSent, totalBattlePoints, contribution
- Family total = sum of all member battle points

### Task 7: Ranking System
- Verify ranking uses total battle points for sorting
- Fix FamilyListScreen sorting to use correct field

### Task 8: Family Level System
- Verify level thresholds in FamilyModel
- Ensure level updates progress dynamically

### Task 9: Family Level Color System
- Create `familyLevelColor(int level)` utility
- Level 1 → Bronze, 2 → Silver, 3 → Gold, 4 → Platinum, 5+ → Premium
- Apply to badge, progress bar, tag, ranking display

### Task 10: Family Progress Bar
- Verify formula: (Current Points / Required Points) × 100
- Ensure real-time updates, no hardcoded values

## Success Criteria
- Accept/Reject on join requests work correctly
- No unrequested features in Clan Command
- No Convert Diamonds section
- Diamond→Points contribution tracked per-member and per-family
- Rankings sorted by total battle points
- Family level colors applied consistently across all screens
- Progress bars show correct percentage
- No console errors
- Data persists after logout/restart
