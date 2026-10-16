# Prompt Auto-Backup GitHub (copy-paste ke chat Muse)

> Cara pakai: copy seluruh isi blok di bawah, paste ke chat Muse, lalu jawab 2 pertanyaan yang dia ajukan (nama repo + folder yang mau di-backup). Semua yang ditanyakan/dijelaskan asisten akan dalam bahasa Indonesia.

---

```
Execute this setup flow step by step until complete, skipping nothing.

LANGUAGE RULE (strict): The instructions below are written in English, but EVERYTHING you say to the user — questions, explanations, confirmations, progress updates, error messages — MUST be in Indonesian (Bahasa Indonesia). Never address the user in English.

GOAL: Auto-backup files to a private GitHub repository, with a cron job that auto-commits + pushes every 1 hour ONLY when files have changed.

====================
STEP 1 — REQUEST CLASSIC TOKEN VIA SECURE CARD
====================
1. Create a secure card for the GitHub token (use credentials.request_api_access). DO NOT proceed to Step 2 until the token is submitted.
2. Include this token creation guide for the user:

   CLASSIC PAT (required):
   - Go to github.com → click profile photo → Settings → Developer settings (bottom of the left sidebar) → Personal access tokens → Tokens (classic) → Generate new token (classic)
   - Note: enter "muse-backup"
   - Expiration: choose as needed (e.g. 90 days / No expiration)
   - Scopes: check `repo` ONLY (full control of private repositories) — no other scopes needed
   - Click Generate new token → copy the token (starts with ghp_) → paste it into the secure card

3. Tell the user explicitly: a token pasted into the secure card is NOT visible to you, and you are FORBIDDEN from writing the token value in chat, files, or memory. The token is only ever used through the secure connector.

====================
STEP 2 — CREATE PRIVATE REPOSITORY
====================
1. Once the classic token is submitted and the GitHub connector is connected, ASK the user: "What should the private repository be named?" (ask in Indonesian).
2. After the user answers, create it via API: POST https://api.github.com/user/repos with body { "name": "<name>", "private": true, "description": "Auto-backup via Muse", "auto_init": false }.
3. Verify via GET /repos/<owner>/<name> and confirm the "private": true field. Report the repo URL to the user.

====================
STEP 3 — REQUEST FINE-GRAINED TOKEN (OPTIONAL, MORE SECURE)
====================
1. Create a second secure card for a fine-grained token.
2. Include this guide (create it AFTER the Step 2 repo exists):
   - Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token
   - Token name: "muse-backup-fine" → Expiration: choose as needed
   - Repository access: select "Only select repositories" → pick the backup repo just created
   - Permissions → Repository permissions: "Contents" = Read and write, "Metadata" = Read (required, automatic)
   - Generate → copy (starts with github_pat_) → paste into the secure card
3. Store it as a SEPARATE connector from the classic one (do not overwrite). The cron will use this fine-grained connector; if the user skips this step, the cron uses the classic connector.

====================
STEP 4 — AUTO-SCAN PROJECTS + INSTALL COMMIT SKILL + INITIAL PUSH
====================
1. AUTO-SCAN: list all top-level project directories in ~/workspace/ (skip hidden/system housekeeping dirs). Present the list to the user IN INDONESIAN with a one-line description of each where identifiable, then ASK which projects to back up (offer "all" as the default choice).
2. Also ASK whether to include standalone utility scripts (e.g. *.ps1 / *.py helpers created in previous sessions).
3. FOLDER STRUCTURE (mandatory — projects must never mix): inside BOTH the backup repo and the local folder ~/workspace/backup-<repo-name>/, create ONE dedicated folder per project, named exactly after the project directory. Standalone scripts go into a folder named scripts/. Example layout:
   backup-<repo-name>/
     dimzmail/
     dimzmail-tgbot/
     api-gateway/
     scripts/
       gh-actions-check.ps1
4. INSTALL COMMIT SKILL (automatic — do not ask, just do it): download the skill from the public shared repo and install it locally, preserving folder structure:
   - https://raw.githubusercontent.com/Kutuyyy/muse-auto-backup/main/skills/commit/SKILL.md → <skills-dir>/commit/SKILL.md
   - https://raw.githubusercontent.com/Kutuyyy/muse-auto-backup/main/skills/commit/references/styles.md → <skills-dir>/commit/references/styles.md
   - .../references/splitting.md, .../references/issue-links.md, .../references/messages.md (same pattern)
   (<skills-dir> = the local skills directory, e.g. ~/workspace/custom-skills/; create it if missing.)
   From this point on, EVERY commit in this flow MUST follow the commit skill: detect the repo's commit style from git log, group changes by intent (per project folder), write a subject stating intent + a body describing what changed. NEVER use a bare "auto-backup: <timestamp>" message.
5. Before pushing, SCAN and automatically EXCLUDE sensitive files: .env, *.env*, *secret*, *token*, *.key, *.pem, credentials*, id_rsa*, plus node_modules/, .git/, __pycache__/ directories.
6. Prepare the local folder as a git repo (git init + initial commit) at ~/workspace/backup-<repo-name>/.
7. Push via the GitHub git-database API, authenticating through the connector (NEVER hardcode the token in a script). Technical pitfalls you MUST avoid:
   - A new repo is EMPTY → seed one commit first via PUT /repos/<owner>/<repo>/contents/README.md (body: message + base64 content). Without this, the git-database API returns 409.
   - Build trees with the Trees API using inline "content" for TEXT files; use the separate blob endpoint only for BINARY files.
   - Update the branch via PATCH /repos/<owner>/<repo>/git/refs/heads/main — note "refs" is PLURAL (the GET endpoint is singular /git/ref/, but PATCH requires plural).
   - The push commit message MUST follow the commit skill (subject + body describing the projects included).
8. Verify: report the number of files pushed + the commit SHA, and confirm each project landed in its own folder.

====================
STEP 5 — HOURLY AUTO-COMMIT CRON
====================
1. Create a cron (cron.add) scheduled at the top of every hour (expression "0 * * * *").
2. Cron instructions (write in full):
   "In ~/workspace/backup-<repo-name>/, run git status --porcelain.
   - If output is EMPTY: nothing changed → do nothing, send no notification, finish.
   - If there ARE changes: git add -A, then commit FOLLOWING THE COMMIT SKILL (installed in Step 4): read git diff --stat, group by project folder, write a subject stating what changed and a body listing per-folder changes. Example:
       auto-backup: 4 files changed in dimzmail, scripts

       - dimzmail/: 3 files (index.js, page.html, worker.js)
       - scripts/: 1 file (gh-actions-check.ps1)
     NEVER use a bare 'auto-backup: <timestamp>' message. Then push using the Step 4 push script with the GitHub connector (fine-grained if available, classic otherwise).
   - If push FAILS: keep the commit locally, log the error, retry on the next schedule. Do not spam the user with notifications."
3. Hard rules: the cron MUST NOT commit when nothing changed; the token MUST NOT be stored in any file.

====================
STEP 6 — FINAL VERIFICATION
====================
Prove and briefly report to the user:
1. The repo exists and is private (show URL).
2. Files are pushed (file count + latest commit SHA).
3. The cron is registered and runs every 1 hour.
4. Sensitive files were NOT pushed (list what was excluded).
5. The commit skill is installed and the push commit message follows it (show the message).
```
