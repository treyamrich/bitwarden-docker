FROM node:20-alpine
RUN apk add --no-cache jq && npm install -g @bitwarden/cli
COPY ./scripts/ /scripts/
RUN chmod +x /scripts/*
# Wrapper cli cmd
RUN mv /scripts/bw-cmd /usr/local/bin/bw-cmd

ENV CONFIG_DIR="/root/.config/Bitwarden CLI"
ENV SESSION_FILE="/root/.config/Bitwarden CLI/session.key"

CMD ["tail", "-f", "/dev/null"]