# Single Primary Repository & Git Workflow Rule

## 1. Single Source of Truth
- **Primary Repository Root**: `D:\UnHuman\Apps\Hello Chat\hellochat`
- **Remote Origin**: `https://github.com/mayurchouhan0111/Hello-Chat.git`
- **Main Branch**: `main`

## 2. Strict Prohibition on Phantom Worktrees
- **NO AGENT-CREATED WORKTREES**: Agents must NEVER run `git worktree add` to create hidden workspaces under `C:\Users\Lenovo\.gemini\antigravity\worktrees\` or `AppData\Local\Temp\` without explicit, written user instruction.
- **WORK DIRECTLY IN THE PRIMARY REPO**: All code edits, file creations, tests, and builds MUST occur directly in `D:\UnHuman\Apps\Hello Chat\hellochat`.

## 3. Strict Single Branch Rule (Always `main`)
- **NO NEW BRANCHES**: Never create feature branches (`feature/*`), verification branches (`verify/*`), or temporary branches. All development occurs directly on `main`.
- **Commit Directly to `main`**: Every completed change, fix, or feature is committed directly to `main` with standard conventional commit syntax (`feat:`, `fix:`, `refactor:`, `test:`).
- **Push Immediately to `origin main`**: After verifying any change, immediately push to GitHub:
  ```bash
  git push origin main
  ```
- `main` on GitHub and `main` in `D:\UnHuman\Apps\Hello Chat\hellochat` must stay 100% synchronized at all times.

## 4. Verification & Build Standard
- All builds (`flutter build apk --release`, `flutter build apk --debug`) MUST be run exclusively from `D:\UnHuman\Apps\Hello Chat\hellochat`.
- The user and agent must always be looking at the same verified files and Git commit hashes.
