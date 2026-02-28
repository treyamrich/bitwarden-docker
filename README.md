# Bitwarden Docker

### Getting Started

```sh
# Build + start container + login to bitwarden
./start.sh

# Run helper scripts
docker exec bitwarden /scripts/upsert.sh "Folder/Item" "username" "password"
docker exec bitwarden /scripts/upsert-note.sh "Folder/Item" "note content here"
docker exec bitwarden /scripts/get-login-pw.sh "Folder/Item"
docker exec bitwarden /scripts/get-secure-note.sh "Folder/Item"
# This is auto ran on start.sh
docker exec bitwarden /scripts/login.sh
# Execute adhoc bitwarden CLI commands from outside of the container
docker exec bitwarden bw-cmd <insert-normal-bitwarden-command-here>
docker exec bitwarden bw-cmd list items ----translates-to---> bw list items
```

### CI — GHCR Image Publishing

Both `bitwarden-cli` and `vault-bootstrap` images are automatically built and pushed to GHCR on version tag push (`v*`). The workflow builds `bitwarden-cli` first (from `Dockerfile`), then `vault-bootstrap` (from `Dockerfile.vault`) which depends on it.

- `ghcr.io/treyamrich/bitwarden-cli:<tag>`
- `ghcr.io/treyamrich/vault-bootstrap:<tag>`

### Dockerfile.vault

An augmented Docker image that adds HashiCorp Vault CLI to the base bitwarden-cli image. The base image is pulled from `ghcr.io/treyamrich/bitwarden-cli:latest`.

```sh
# Build the vault variant (default VAULT_VERSION=1.21)
docker build -f Dockerfile.vault -t vault-bootstrap:latest .

# Build with a specific vault version
docker build -f Dockerfile.vault --build-arg VAULT_VERSION=1.18 -t vault-bootstrap:latest .

# Verify
docker run --rm vault-bootstrap:latest vault version
docker run --rm vault-bootstrap:latest bw --version
```

### upsert-note.sh

Creates or updates a Bitwarden secure note.

```sh
# Create/update a secure note
docker exec bitwarden /scripts/upsert-note.sh "Folder/Item" "note content here"
```
