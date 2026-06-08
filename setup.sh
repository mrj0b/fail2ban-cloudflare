#!/bin/bash
# Fail2Ban + Cloudflare Auto-Installer
# This script installs Fail2Ban and configures it to ban attackers at the Cloudflare Edge network.

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo ./setup.sh)"
  exit
fi

echo "Enter your Cloudflare API Token:"
read CF_TOKEN
echo "Enter your Cloudflare Zone ID:"
read CF_ZONE

echo "Installing Fail2Ban from package manager..."
apt update && apt install -y fail2ban curl jq

echo "Creating Cloudflare Action..."
cat << 'EOF' > /etc/fail2ban/action.d/cloudflare-token.conf
[Definition]
actionstart = 
actionstop = 
actioncheck = 
actionban = curl -s -X POST "https://api.cloudflare.com/client/v4/zones/<cfzone>/firewall/access_rules/rules" \
            -H "Authorization: Bearer <cftoken>" \
            -H "Content-Type: application/json" \
            --data '{"mode":"block","configuration":{"target":"<ip_type>","value":"<ip>"},"notes":"Fail2Ban <name>"}'
actionunban = id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<cfzone>/firewall/access_rules/rules?mode=block&configuration_target=<ip_type>&configuration_value=<ip>&match=all" \
              -H "Authorization: Bearer <cftoken>" \
              -H "Content-Type: application/json" | jq -r '.result[0].id' | grep -v null) && \
              if [ -n "$id" ]; then curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/<cfzone>/firewall/access_rules/rules/$id" \
              -H "Authorization: Bearer <cftoken>" \
              -H "Content-Type: application/json"; fi

[Init]
cftoken =
cfzone =

[Init?family=inet6]
ip_type = ip6

[Init?family=inet4]
ip_type = ip
EOF

echo "Creating Jail Local Configuration..."
cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
# Ban for 2 hours
bantime = 7200
findtime = 600
maxretry = 5
banaction = cloudflare-token[cftoken="$CF_TOKEN", cfzone="$CF_ZONE"]
banaction_allports = cloudflare-token[cftoken="$CF_TOKEN", cfzone="$CF_ZONE"]

[nginx-limit-req]
enabled = true
port    = http,https
logpath = /home/mrj0b/*/logs/error.log
filter  = nginx-limit-req

[nginx-botsearch]
enabled = true
port    = http,https
logpath = /home/mrj0b/*/logs/error.log
maxretry = 2
filter  = nginx-botsearch
EOF

echo "Restarting Fail2Ban and Nginx..."
systemctl reload nginx
systemctl restart fail2ban

echo "Installation Complete! Check status with: sudo fail2ban-client status"
