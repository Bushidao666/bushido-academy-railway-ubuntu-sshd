FROM ubuntu:22.04

# Evita perguntas interativas durante o apt upgrade (impede que o deploy trave)
ENV DEBIAN_FRONTEND=noninteractive

# Remove o usuário ubuntu padrão para liberar o UID/GID 1000
RUN userdel -r ubuntu 2>/dev/null || true

# 1. Atualização do Sistema e Instalação de Dependências Básicas + Python + Setup do Node.js
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y \
       curl \
       gnupg \
       ca-certificates \
       python3 \
       python3-pip \
       python3-venv \
       build-essential \
       iproute2 \
       iputils-ping \
       openssh-server \
       telnet \
       sudo \
       git \
    # Configura o repositório do Node.js 20 (LTS) - Essencial para ferramentas de IA recentes
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    # Limpeza para reduzir o tamanho da imagem
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 2. Instalação das CLIs de IA via NPM (Global)
# Nota: Se algum nome de pacote estiver errado no registro do NPM, o build vai falhar.
# Agrupamos aqui para facilitar a manutenção.
RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    @google/gemini-cli \
    @qwen-code/qwen-code \
    # Adicionei typescript e ts-node que essas ferramentas costumam usar internamente
    typescript \
    ts-node

# 3. Configuração do SSH (Mantendo sua config original)
RUN mkdir -p /run/sshd \
    && chmod 755 /run/sshd \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    # Disable root login (embora você use user configs, é boa prática manter a config base segura)
    && echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Copy ssh user config to configure user's password and authorized keys
COPY ssh-user-config.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/ssh-user-config.sh

# Expose port 22
EXPOSE 22

# Start SSH server
CMD ["/usr/local/bin/ssh-user-config.sh"]
