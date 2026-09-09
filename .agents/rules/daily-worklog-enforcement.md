# Mandatory Rule: Maintain Daily Plain-English Work Log

## Requirement
Whenever ANY work, change, bug fix, or feature is completed for the client:
The AI MUST update [`PROJECT_WORKLOG.md`](../../PROJECT_WORKLOG.md) located in the project root.

## Language and Tone Guidelines
- **Plain English**: Write in simple, crystal-clear language that anyone (non-technical clients, managers, and developers) can understand immediately.
- **No Heavy Jargon**: Avoid obscure abbreviations or ungrounded explanations. Explain *what broke / was requested* and *how it was solved* in practical terms.
- **Reverse Chronological**: Place new entries at the top under `## Work Log Entries (Newest First)`.

## Entry Template
```markdown
### Date: YYYY-MM-DD
- **What Client Asked / Problem**:
  [Plain language explanation of the request or reported issue]
- **What We Did**:
  [Plain language explanation of the solution, root cause, and changes made]
- **Files Touched**:
  - `path/to/file`
- **Status**: Completed / In Progress / Testing
```
