# Muse GitHub Auto-Backup

Hourly, fully automatic backups of your files to a **private** GitHub repository — set up by pasting a single prompt into Muse. No manual commits, no exposed tokens, no sensitive files leaking.

## What it does

- **Auto-scans** your workspace and lists every project it finds — you just pick which ones to back up (or take all).
- Gives **each project its own dedicated folder** inside the backup repo (`dimzmail/`, `dimzmail-tgbot/`, `api-gateway/`, …) plus a `scripts/` folder for standalone utilities — nothing ever mixes.
- Creates a **private** GitHub repository for your backups.
- Installs an **hourly cron job** that commits and pushes **only when files actually changed**. No changes → no commit, no noise.
- Automatically **excludes secrets**: `.env`, `*secret*`, `*token*`, `*.key`, `*.pem`, credentials, SSH keys, `node_modules/`, etc.
- Authenticates through Muse's **secure connector** — your token is entered via a secure card, never visible in chat, never written to files.

## Requirements

- A GitHub account.
- A Muse chat (this is where you paste the prompt).
- 2 minutes of your time to answer two questions: *repository name* and *which folders to back up*.

## Getting your tokens

You'll need **two** GitHub tokens. Create the **classic** one first (it's used to create the repository); the **fine-grained** one is created after the repo exists.

### 1. Classic PAT (required)

1. Go to [github.com](https://github.com) → click your profile photo (top right) → **Settings**.
2. Scroll to the bottom of the left sidebar → **Developer settings** → **Personal access tokens** → **Tokens (classic)**.
3. Click **Generate new token (classic)**.
4. Fill in:
   - **Note:** `muse-backup`
   - **Expiration:** choose as needed (e.g. `90 days` or `No expiration`)
   - **Scopes:** check **`repo`** ONLY (full control of private repositories) — nothing else is needed.
5. Click **Generate token**, then **copy it** (it starts with `ghp_`). GitHub shows it only once — if you lose it, generate a new one.

### 2. Fine-grained PAT (recommended — least privilege)

> Create this **after** the backup repository exists (the setup assistant creates it for you in step 2).

1. Go to **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**.
2. Click **Generate new token**.
3. Fill in:
   - **Token name:** `muse-backup-fine`
   - **Expiration:** choose as needed
   - **Resource owner:** your account
   - **Repository access:** select **Only select repositories** → pick your backup repository
   - **Permissions** → **Repository permissions**: set **Contents** to **Read and write**; **Metadata** stays **Read-only** (required, selected automatically).
4. Click **Generate token**, then **copy it** (it starts with `github_pat_`).

### Why two tokens?

| Token | Used for | Why |
|---|---|---|
| Classic (`repo` scope) | Creating the repository + first push | Fine-grained tokens **cannot** create repositories on GitHub |
| Fine-grained (`Contents` read/write) | Hourly auto-push | Minimal access: can only touch the backup repo, nothing else |

Both tokens are entered through Muse's **secure card** — never pasted in chat, never stored in files.

## Usage

1. Copy the full prompt from [`prompt-auto-backup-github.md`](prompt-auto-backup-github.md).
2. Paste it into your Muse chat.
3. The assistant will:
   1. Ask for your GitHub tokens via **secure cards** (classic PAT for repo creation, optional fine-grained PAT for least-privilege daily operation) — with a step-by-step guide including exact scopes: classic → `repo` scope only; fine-grained → `Contents: Read and write` + `Metadata: Read` on the backup repo.
   2. Ask what you want to name the private repository, then create it.
   3. **Auto-scan your workspace**, show you the projects it found, and let you pick which to back up — each project gets its **own folder** in the repo (`dimzmail/`, `dimzmail-tgbot/`, …, `scripts/` for standalone utilities).
   4. Scan everything for secrets, then push the initial commit.
   5. Install the hourly auto-commit cron.
   6. Verify everything and report back: repo URL, files pushed, cron schedule, excluded secrets.

> Note: the assistant communicates with you in **Indonesian (Bahasa Indonesia)** throughout the setup.

## How the hourly backup works

Every hour, on the hour, the cron job runs:

```
git status --porcelain   →   empty?  → do nothing, stay silent
                              |
                           changed? → git add -A → commit ("auto-backup: <timestamp>") → push
```

- If a push fails (network issue, rate limit), the commit stays local and is retried on the next run — you won't get spammed.
- The GitHub token is never stored in any file; every API call authenticates through the secure connector.

## Security model

| Concern | How it's handled |
|---|---|
| Token exposure | Entered via secure card; never visible in chat, files, or memory |
| Token scope | Classic PAT: `repo` scope only. Fine-grained PAT: `Contents` read/write on the backup repo only |
| Secret files | Auto-excluded before every push (`.env`, keys, tokens, credentials, …) |
| Repository visibility | Always created as **private** and verified via API |

## Troubleshooting

**Push fails with `409` on a new repo**
The git-database API rejects pushes to completely empty repositories. The setup seeds an initial commit through the Contents API (`PUT /repos/{owner}/{repo}/contents/README.md`) before the first tree push — this is handled automatically.

**`404` when updating the branch ref**
Branch updates must use the plural endpoint: `PATCH /repos/{owner}/{repo}/git/refs/heads/main`. (The GET endpoint is singular `/git/ref/` — the PATCH one is not.)

**Slow or flaky uploads with many files**
Text files are pushed inline via the Trees API (`content` field). Only binary files use the separate blob endpoint.

**Fine-grained token can't create repositories**
Expected — fine-grained PATs cannot create repos on GitHub. That's why the flow uses the classic PAT (with `repo` scope) for repository creation, and the fine-grained token only for day-to-day pushes.

## What's inside

- `prompt-auto-backup-github.md` — the complete copy-paste setup prompt.
- `scripts/gh-actions-check.ps1` — check GitHub Actions artifacts (has content / empty / expired) and re-run dead workflows, from PowerShell.
- `skills/commit/` — a commit skill: turns a dirty working tree into a clean series of well-described commits (detects the repo's commit style, groups changes by intent, writes subject + body). Includes reference guides: styles, splitting, issue links, message templates.
- `README.md` — this file.

## License

MIT — use it, fork it, share it with your community.
