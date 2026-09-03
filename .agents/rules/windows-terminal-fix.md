---
name: windows-terminal-fix
description: On Windows, shell commands executed by the agent must use the cmd /c prefix so the process terminates and closes the ConPTY pipe. Without this, commands hang forever on "Working..".
---

# Windows Terminal Fix

## Critical: Shell Command Execution on Windows

On Windows, shell commands executed by the agent's bash tool MUST use `cmd /c` prefix to ensure the process terminates and sends EOF. Without this, commands hang forever on "Working.." because the ConPTY pipe never closes.

### Required Pattern

Always prefix shell commands with `cmd /c` and wrap in quotes:

```
cmd /c "your-command-here"
```

### Examples

**Git commands:**
```
cmd /c "git status"
cmd /c "git add ."
cmd /c "git commit -m 'message'"
cmd /c "git push origin main"
cmd /c "git pull"
```

**Flutter/Dart commands:**
```
cmd /c "flutter pub get"
cmd /c "flutter build apk"
cmd /c "dart analyze"
```

**Node.js commands:**
```
cmd /c "npm install"
cmd /c "npm run build"
cmd /c "npx flutterfire configure"
```

**ADB commands:**
```
cmd /c "adb devices"
cmd /c "adb shell pm list packages"
```

### Environment Variables for Git

If git commands hang, set these environment variables first:

```
cmd /c "set GIT_TERMINAL_PROMPT=0 && set GIT_PAGER=cat && set CI=true && git status"
```

### Timeout Pattern

For long-running commands, add a timeout:

```
cmd /c "timeout /t 30 /nobreak >nul && your-command"
```

### What NOT to Do

- Do NOT run commands without `cmd /c` prefix on Windows
- Do NOT use `bash -c` (Git Bash may also hang)
- Do NOT use interactive commands that wait for user input
- Do NOT run commands that spawn long-running child processes without `cmd /c`

### Root Cause

The Antigravity language server (Go binary) spawns processes using Windows ConPTY. When a process completes, the ConPTY pipe doesn't close properly on Windows, causing the agent to wait forever for EOF. Using `cmd /c` forces the process to terminate cleanly and close the pipe.
