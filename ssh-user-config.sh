#!/bin/bash

# Set SSH_USERNAME and SSH_PASSWORD by default or create an .env file (refer to.env.example)
: ${SSH_USERNAME:="myuser"}
: ${SSH_PASSWORD:="mypassword"}

# Set root password if root login is enabled
: ${ROOT_PASSWORD:=""}
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "Root password set"
else
    echo "Root password not set"
fi

# Set authorized keys if applicable
: ${AUTHORIZED_KEYS:=""}

# Check if SSH_USERNAME or SSH_PASSWORD is empty and raise an error
if [ -z "$SSH_USERNAME" ] || [ -z "$SSH_PASSWORD" ]; then
    echo "Error: SSH_USERNAME and SSH_PASSWORD must be set." >&2
    exit 1
fi

# Create the user with the provided username and set the password
if id "$SSH_USERNAME" &>/dev/null; then
    echo "User $SSH_USERNAME already exists"
else
    useradd -ms /bin/bash "$SSH_USERNAME"
    echo "$SSH_USERNAME:$SSH_PASSWORD" | chpasswd
    # Add user to sudo group
    usermod -aG sudo "$SSH_USERNAME"
    echo "User $SSH_USERNAME created with the provided password and added to sudo group"
fi

# Set the authorized keys from the AUTHORIZED_KEYS environment variable (if provided)
if [ -n "$AUTHORIZED_KEYS" ]; then
    mkdir -p /home/$SSH_USERNAME/.ssh
    echo "$AUTHORIZED_KEYS" > /home/$SSH_USERNAME/.ssh/authorized_keys
    chown -R $SSH_USERNAME:$SSH_USERNAME /home/$SSH_USERNAME/.ssh
    chmod 700 /home/$SSH_USERNAME/.ssh
    chmod 600 /home/$SSH_USERNAME/.ssh/authorized_keys
    echo "Authorized keys set for user $SSH_USERNAME"
    # Disable password authentication if authorized keys are provided
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
else
    echo "Authorized keys not set"
fi

# Start the SSH server
echo "Starting SSH server..."
exec /usr/sbin/sshd -D
