# bitwarden-docker: Vault Unseal Keys Implementation Plan

**Date:** 2026-02-22
**Feature Name:** `vault-unseal-keys`

---

## 1. Feature Overview

This is part of a cross-repo feature to store HashiCorp Vault unseal keys securely in Bitwarden instead of plain text on disk. The complete feature spans three repositories:

1. **bitwarden-docker** (this repo): Provides augmented Docker image with Vault CLI and extended scripts
2. **argoapps-homelab**: Deploys OCI registry and redesigns vault bootstrap-job to use augmented image
3. **server-provision**: Configures K3s, builds/pushes custom images, integrates into bootstrap pipeline

**End-to-end workflow:**
- User runs bootstrap script on bare-metal host
- bitwarden-docker image is fetched and built (v1.1.0)
- server-provision builds Dockerfile.vault variant and pushes to in-cluster OCI registry
- Vault bootstrap-job uses augmented image to initialize vault
- Job waits for interactive `kubectl exec login.sh` to establish bitwarden session
- Job initializes vault, stores unseal keys + root token in Bitwarden under "Homelab/Hashicorp Vault Unseal Keys"
- Plain text init.txt deleted from disk

---

## 2. System Context

| Field | Value |
|---|---|
| System Plan | `/workspace/docs/homelab/plans/2026-02-22-vault-unseal-keys.md` |
| Feature Name | `vault-unseal-keys` |
| This Repo's Role | Augmented Docker image (`Dockerfile.vault`) with Vault CLI + extended `upsert.sh` with notes field |
| Depends on | Nothing — this repo is implemented first |
| Depended on by | server-provision (fetches v1.1.0, builds vault variant), argoapps-homelab (bootstrap-job uses augmented image + upsert.sh) |

---

## 3. Overview

This repo builds two artifacts for release v1.1.0:

### Dockerfile.vault
A multi-stage Docker build that augments the existing bitwarden-cli image with Vault CLI:
- **Stage 1:** Pulls Vault binary from `hashicorp/vault:${VAULT_VERSION}` image
- **Stage 2:** Builds from `bitwarden-cli:latest` base and copies vault binary to `/usr/local/bin/vault`
- **Result:** Image with vault, bw CLI, jq, and all helper scripts

### Extended upsert.sh
Current: Takes 3 arguments (FOLDER/ITEM, USERNAME, PASSWORD).
Enhanced: Takes 3-4 arguments, with optional 4th arg as notes field.
- **Backward compatible:** 3-arg calls continue to work
- **4-arg calls:** Set the `.notes` field on the login item

---

## 4. Current State Analysis

### Dockerfile (lines 1-11)
- Line 1: `FROM node:20-alpine` — Alpine base with Node.js
- Line 2: `RUN apk add --no-cache jq && npm install -g @bitwarden/cli` — jq + bitwarden CLI
- Lines 3-6: Copy scripts, chmod, move bw-cmd to PATH
- Lines 8-9: `ENV CONFIG_DIR` and `ENV SESSION_FILE` — session persistence paths
- Line 11: `CMD ["tail", "-f", "/dev/null"]` — keep container alive for exec

### start.sh (lines 1-20)
- Lines 3-5: Cleanup existing container/image (`docker rm -f`, `docker image rm`)
- Line 11: `IMAGE="bitwarden-cli:latest"` — image name constant
- Line 14: `docker build -t "$IMAGE" .` — builds from Dockerfile
- Lines 15-18: `docker run -d --name bitwarden -v ...` — starts with volume mount for session persistence
- Line 20: `docker exec bitwarden /scripts/login.sh` — interactive login

### scripts/upsert.sh (lines 1-73)
- Lines 5-7: Capture 3 positional args: `ITEM_PATH`, `USERNAME`, `PASSWORD`
- Lines 9-12: Validate all 3 are provided, exit if not
- Line 15: `export BW_SESSION=$(cat "$SESSION_FILE")` — load session
- Lines 18-19: Split ITEM_PATH into FOLDER and ITEM_NAME via `dirname`/`basename`
- Lines 22-33: Folder lookup/create — idempotent (`bw list folders`, `bw create folder` if missing)
- Lines 36-37: Item lookup — `bw list items --folderid` + jq filter
- Lines 39-53: CREATE path — `bw get template item | jq ... | bw encode | bw create item`
  - jq filter sets: `.type = 1`, `.name`, `.login.username`, `.login.password`, `.folderId`
- Lines 55-70: UPDATE path — same jq template piped to `bw edit item "$ITEM_ID"`
- Line 72: Success message

### scripts/login.sh (lines 1-34)
- Lines 7-18: `renew_session()` — `bw login`, `bw unlock --raw`, save to `$SESSION_FILE`
- Lines 21-30: Check for existing session file, reuse if valid, renew if not
- Lines 32-33: `bw sync` after login

### scripts/bw-cmd (lines 1-4)
- Loads `BW_SESSION` from session file, forwards all args to `bw`

### scripts/get-login-pw.sh (lines 1-24)
- Retrieves password from FOLDER/ITEM path — returns plain text via jq

---

## 5. Desired End State

After Phase 1 completion:

1. **Dockerfile.vault** exists alongside Dockerfile in repo root
   - Multi-stage build: copies vault binary from `hashicorp/vault:${VAULT_VERSION}`
   - Uses `bitwarden-cli:latest` as base (requires `start.sh` to build it first)
   - Accepts `VAULT_VERSION` build arg (default: `1.21`)

2. **scripts/upsert.sh** accepts 3-4 arguments
   - 3 args: backward compatible, no notes set
   - 4 args: sets `.notes` field on item (create and update paths)

3. **README.md** documents Dockerfile.vault usage and upsert.sh notes parameter

4. **Release v1.1.0** on GitHub — tarball contains all new files

---

## 6. Key Discoveries

1. **Session file is the contract:** `login.sh` writes to `$SESSION_FILE` at `/root/.config/Bitwarden CLI/session.key`. All scripts load it. The bootstrap-job will wait for this file to exist as the signal that bitwarden is unlocked.

2. **Idempotent upsert pattern is established:** `upsert.sh` already handles create-or-update. Adding notes is a natural extension of the jq template filter.

3. **Multi-stage build is cleanest:** Copying `/bin/vault` from the official HashiCorp image avoids manual binary downloads, APK repo dependencies, and ensures exact version control.

4. **`bitwarden-cli:latest` is the build dependency:** `Dockerfile.vault` uses this as its base. `start.sh` builds it. server-provision runs `start.sh` before building the vault variant.

5. **jq is the JSON tool:** All scripts use jq for template manipulation. The notes field extension just adds another `--arg` and conditional in the jq filter.

---

## 7. Architecture Impact

| Layer | Current | After Change |
|---|---|---|
| Docker Image (base) | Single Dockerfile: Alpine + Node.js + jq + bw CLI + scripts | No changes to base Dockerfile |
| Docker Image (vault) | None | New `Dockerfile.vault`: multi-stage, copies vault binary into bitwarden-cli base |
| scripts/upsert.sh | 3 args: FOLDER/ITEM, USERNAME, PASSWORD | 3-4 args: optional 4th arg sets `.notes` field |
| scripts/login.sh | No changes | No changes |
| scripts/bw-cmd | No changes | No changes |
| scripts/get-login-pw.sh | No changes | No changes |
| Release | v1.0.1 | v1.1.0 |

---

## 8. Error Handling Approach

Follow existing `set -e` pattern:

- **upsert.sh notes handling:** `NOTES="${4:-}"` defaults to empty string. jq conditional `if $notes != "" then .notes = $notes else . end` ensures empty/missing 4th arg doesn't set notes.
- **Dockerfile.vault build errors:** If `bitwarden-cli:latest` doesn't exist locally, COPY fails with clear error. If `hashicorp/vault:${VAULT_VERSION}` can't be pulled, build fails at stage 1.
- **Existing error propagation preserved:** `set -e` in upsert.sh means any `bw` command failure exits immediately.

---

## 9. What We're NOT Doing

- Not modifying the base Dockerfile (consumers of original image unaffected)
- Not adding vault-specific scripts (vault bootstrap logic lives in argoapps-homelab)
- Not changing start.sh (vault variant is built by server-provision's build script)
- Not adding login.sh non-interactive mode (bootstrap-job uses kubectl exec for interactive login)
- Not adding key rotation automation
- Not deploying the OCI registry (that's argoapps-homelab)

---

## 10. Implementation Approach

**Philosophy:** Minimal, non-invasive changes. New file (Dockerfile.vault), extend existing script (upsert.sh with backward compatibility), update documentation.

**Dockerfile.vault strategy:** Multi-stage build avoids manual binary handling and keeps image reproducible. VAULT_VERSION build arg lets server-provision control the vault version at build time. Using `bitwarden-cli:latest` as base ensures consistency with start.sh.

**upsert.sh strategy:** Shell parameter expansion `${4:-}` defaults to empty string. Pass to jq as `--arg notes "$NOTES"`. Conditional `.notes` assignment in both create and update paths. Fully backward compatible.

---

## 11. Phases

### Phase 1: Augment with Vault CLI + Notes Support

#### Task 1: Create Dockerfile.vault [x]

**File:** `/workspace/bitwarden-docker/Dockerfile.vault` (new)

**Content:**
```dockerfile
ARG VAULT_VERSION=1.21
FROM hashicorp/vault:${VAULT_VERSION} AS vault

FROM bitwarden-cli:latest
COPY --from=vault /bin/vault /usr/local/bin/vault
```

**Why:** Adds vault CLI without modifying base. Multi-stage avoids manual downloads. `bitwarden-cli:latest` base means start.sh must run first. VAULT_VERSION arg allows version control at build time.

#### Task 2: Create upsert-note.sh for secure notes [x]

**File:** `/workspace/bitwarden-docker/scripts/upsert-note.sh` (new)

**Changes:**
- New script based on upsert.sh patterns (folder lookup/create, idempotent create-or-update)
- Takes 2 args: FOLDER/ITEM_NAME, NOTES_CONTENT
- Creates Bitwarden secure note (type 2) instead of login item
- Sets `.secureNote.type = 0`, `.notes = $notes`, nulls `.login`
- upsert.sh left unchanged — clean separation between login items and secure notes

**Why:** The notes field on login items wasn't being applied by the Bitwarden CLI template pipeline. Secure notes (type 2) are a better fit for vault unseal keys — they're text content, not credentials.

#### Task 3: Update README.md [x]

**File:** `/workspace/bitwarden-docker/README.md`

**Changes:**
- Add "Dockerfile.vault" section documenting: purpose, build command, VAULT_VERSION arg, dependency on bitwarden-cli:latest
- Update upsert.sh docs with 4-arg signature and example with notes

**Why:** Users of this repo need to know about the vault variant and extended API.

### Verification (Phase 1)

**Automated:**
- `docker build -t bitwarden-cli:latest .` succeeds (base image)
- `docker build -f Dockerfile.vault --build-arg VAULT_VERSION=1.21 -t vault-bootstrap:test .` succeeds
- `docker run --rm vault-bootstrap:test vault version` outputs vault version
- `docker run --rm vault-bootstrap:test bw --version` outputs bitwarden CLI version
- `docker run --rm vault-bootstrap:test which jq` returns 0

**Manual:**
- Start container with `./start.sh`, log in, then test:
  - `docker exec bitwarden /scripts/upsert.sh "Test/Notes Item" "user" "pass" "my notes"` — verify item created with notes
  - `docker exec bitwarden /scripts/upsert.sh "Test/Notes Item" "user" "pass2" "updated notes"` — verify update
  - `docker exec bitwarden /scripts/upsert.sh "Test/No Notes" "user" "pass"` — verify 3-arg still works

---

## 12. Execution Log

| Phase | Status | Date | Notes |
|---|---|---|---|
| Phase 1 | Complete | 2026-02-22 | Verified by user — secure note approach replaces login notes approach |
| Review | Completed | 2026-02-22 | Fresh-context review pass — 1 fix applied |

### Session: 2026-02-22
**Status**: complete
**Phase**: 1
**Branch**: main
**Starting Commit**: c8d4a8b
**Last Completed Task**: Task 3

**Actions Taken:**
- Created `Dockerfile.vault` — multi-stage build copying vault binary from `hashicorp/vault:${VAULT_VERSION}` into `bitwarden-cli:latest`
- Created `scripts/upsert-note.sh` — new script for secure notes (type 2), replacing the failed approach of adding notes to login items via upsert.sh
- Reverted upsert.sh to original state (notes field on login items wasn't applied by bw CLI template pipeline)
- Updated `README.md` with Dockerfile.vault docs and upsert-note.sh usage

**Files Modified:**
- `Dockerfile.vault` (new)
- `scripts/upsert-note.sh` (new)
- `README.md` (modified)

### Session: 2026-02-22 (Review)
**Status**: completed
**Phase**: review

#### Actions Taken
- Reviewed all changed files against codebase patterns
- Fixed: Reverted `scripts/upsert.sh` trailing whitespace changes left behind from implementation session (2 blank lines had trailing spaces removed during implementation, not fully reverted)
- Verified `Dockerfile.vault` — clean 5-line multi-stage build, no issues
- Verified `scripts/upsert-note.sh` — follows all established patterns from `upsert.sh` (shebang, set -e, session loading, folder logic, create-or-update), correct secure note structure
- Verified `README.md` — improved existing examples with actual arguments, new sections are clear
- No debug code, dead code, or unnecessary complexity found
- Review complete

#### Notes
Implementation is clean. The only issue was `scripts/upsert.sh` appearing in the diff with cosmetic-only trailing whitespace changes — reverted to match origin/main exactly so it won't appear in the commit.
