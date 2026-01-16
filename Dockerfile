FROM ubuntu:22.04

# --- SUA CONFIGURAÇÃO ORIGINAL ---
# Remove the default ubuntu user to free up UID/GID 1000
RUN userdel -r ubuntu 2>/dev/null || true

# Evita travar o deploy com perguntas
ENV DEBIAN_FRONTEND=noninteractive

# --- AQUI ENTRAM APENAS AS ADIÇÕES QUE VOCÊ PEDIU + WGET (Necessário pro VS Code) ---
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
    # Seus pacotes originais:
    iproute2 iputils-ping openssh-server telnet sudo \
    # Dependências para as ferramentas que você pediu:
    wget \
    curl \
    git \
    python3 \
    python3-pip \
    build-essential \
    # Instalação do Node.js 20 (Necessário para as CLIs de IA)
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    # Instalação das CLIs Globais solicitadas
    && npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli @qwen-code/qwen-code \
    # Limpeza
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# --- VOLTA PARA SUA CONFIGURAÇÃO ORIGINAL (SEM ALTERAÇÕES) ---
RUN mkdir -p /run/sshd \
    && chmod 755 /run/sshd \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    # Disable root login
    && echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Copy ssh user config to configure user's password and authorized keys
COPY ssh-user-config.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/ssh-user-config.sh

# Expose port 22
EXPOSE 22

# Start SSH server
CMD ["/usr/local/bin/ssh-user-config.sh"]
