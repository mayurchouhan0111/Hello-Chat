# Single Primary Repository & Git Workflow Rule

## 1. Single Source of Truth
- **Primary Repository Root**: `D:\UnHuman\Apps\Hello Chat\hellochat`
- **Remote Origin**: `https://github.com/mayurchouhan0111/Hello-Chat.git`
- **Main Branch**: `main`

## 2. Strict Prohibition on Phantom Worktrees
- **NO AGENT-CREATED WORKTREES**: Agents must NEVER run `git worktree add` to create hidden workspaces under `C:\Users\Lenovo\.gemini\antigravity\worktrees\` or `AppData\Local\Temp\` without explicit, written user instruction.
- **WORK DIRECTLY IN THE PRIMARY REPO**: All code edits, file creations, tests, and builds MUST occur directly in `D:\UnHuman\Apps\Hello Chat\hellochat`.

## 3. Commit & Push Protocol
- **Commit Early & Atomically**: Every completed module, bugfix, or feature slice must be committed with standard conventional commit syntax (`feat:`, `fix:`, `refactor:`, `test:`).
- **Push Immediately to GitHub**: Never leave verified work unpushed in local branches or working trees. After completing verification, push the branch to `origin`:
  ```bash
  git push origin <branch-name>
  ```
- **Sync Primary Branch**: When a feature/milestone is verified, merge it into `main` (or create a GitHub PR) so `main` is always clean, buildable, and ready for deployment.

## 4. Verification & Build Standard
- All builds (`flutter build apk --release`, `flutter build apk --debug`) MUST be run exclusively from `D:\UnHuman\Apps\Hello Chat\hellochat`.
- The user and agent must always be looking at the same verified files and Git commit hashes.
