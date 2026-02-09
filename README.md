# Bitwarden Docker

### Getting Started

```sh
# Build + start container + login to bitwarden
./start.sh

# Run helper scripts
docker exec bitwarden /scripts/upsert.sh
docker exec bitwarden /scripts/get-login-pw.sh
# This is auto ran on start.sh
docker exec bitwarden /scripts/login.sh
# Execute adhoc bitwarden CLI commands from outside of the container
docker exec bitwarden bw-cmd <insert-normal-bitwarden-command-here>
docker exec bitwarden bw-cmd list items ----translates-to---> bw list items
```
