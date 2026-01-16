FROM ubuntu:22.04

# Evita prompts interativos durante upgrade/install
ARG DEBIAN_FRONTEND=noninteractive

# Escolhe a major do Node (22 é uma boa default hoje)
ARG NODE_MAJOR=22

# Remove o usuário ubuntu (caso exista) pra liberar UID/GID 1000
RUN userdel -r ubuntu 2>/dev/null || true

# Base + SSH + Python + Node + CLIs
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg \
      git build-essential \
      python3 python3-pip python3-venv python-is-python3 \
      iproute2 iputils-ping openssh-server telnet sudo; \
    \
    # Node.js via NodeSource
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs; \
    \
    # NPM: menos barulho
    npm config set fund false; \
    npm config set audit false; \
    \
    # Instala CLIs
    npm install -g \
      @anthropic-ai/claude-code \
      @openai/codex \
      @google/gemini-cli \
      @qwen-code/qwen-code; \
    npm cache clean --force; \
    \
    # SSH runtime dir + config
    mkdir -p /run/sshd; \
    chmod 755 /run/sshd; \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config; \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config; \
    \
    # limpa pra reduzir imagem
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy ssh user config to configure user's password and authorized keys
COPY ssh-user-config.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/ssh-user-config.sh

EXPOSE 22

# Start SSH server
CMD ["/usr/local/bin/ssh-user-config.sh"]
