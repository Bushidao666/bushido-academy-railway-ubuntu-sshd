FROM ubuntu:22.04

# Starting Ubuntu 24.04 official docker image has user ubuntu with UID/GID 1000
# Remove the default ubuntu user to free up UID/GID 1000
RUN userdel -r ubuntu 2>/dev/null || true

# Install dependencies with disable root login for security reasons
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        iproute2 iputils-ping openssh-server telnet sudo git zsh \
        wget tar ca-certificates curl gnupg \
        python3 python3-pip python3-venv python-is-python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && mkdir -p /run/sshd \
    && chmod 755 /run/sshd \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    # Disable root login
    && echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# --- ADD: Node.js + CLIs ---
# NodeSource repo (Node 22). Se quiser outra major, me diga e eu troco o "22" por "20" etc.
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code \
                      @openai/codex \
                      @google/gemini-cli \
                      @qwen-code/qwen-code \
    && npm cache clean --force \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy ssh user config to configure user's password and authorized keys
COPY ssh-user-config.sh /usr/local/bin/
COPY scripts/install-bushido-zsh-global.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/ssh-user-config.sh /usr/local/bin/install-bushido-zsh-global.sh \
    && /usr/local/bin/install-bushido-zsh-global.sh

# Expose port 22
EXPOSE 22

# Start SSH server
CMD ["/usr/local/bin/ssh-user-config.sh"]
