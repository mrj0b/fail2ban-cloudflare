#!/bin/bash
# Fail2Ban + Cloudflare Auto-Installer
# This script installs Fail2Ban and configures it to ban attackers at the Cloudflare Edge network.

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo ./setup.sh)"
  exit
fi

echo "How many Cloudflare zones (domains) do you want to protect?"
read ZONE_COUNT

if ! [[ "$ZONE_COUNT" =~ ^[0-9]+$ ]] || [ "$ZONE_COUNT" -lt 1 ]; then
    echo "Invalid number of zones. Exiting."
    exit 1
fi

ZONES=()
TOKENS=()
LOG_PATHS=()

for (( i=1; i<=ZONE_COUNT; i++ )); do
    echo "--- Domain $i ---"
    echo "Enter Cloudflare API Token for Domain $i:"
    read TOKEN
    echo "Enter Cloudflare Zone ID for Domain $i:"
    read ZONE
    echo "Enter Nginx error log path for Domain $i (e.g. /var/log/nginx/error.log):"
    read LOG_PATH
    
    ZONES+=("$ZONE")
    TOKENS+=("$TOKEN")
    LOG_PATHS+=("$LOG_PATH")
done

echo "Installing Fail2Ban from package manager..."
apt update && apt install -y fail2ban curl jq

echo "Creating Cloudflare Action..."
cat << 'EOF' > /etc/fail2ban/action.d/cloudflare-token.conf
[Definition]
actionstart = 
actionstop = 
actioncheck = 
EOF

echo -n "actionban = " >> /etc/fail2ban/action.d/cloudflare-token.conf
for (( i=0; i<ZONE_COUNT; i++ )); do
    ZONE="${ZONES[$i]}"
    TOKEN="${TOKENS[$i]}"
    if [ $i -gt 0 ]; then
        echo -n "            " >> /etc/fail2ban/action.d/cloudflare-token.conf
    fi
    echo "curl -s -X POST \"https://api.cloudflare.com/client/v4/zones/$ZONE/firewall/access_rules/rules\" \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "            -H \"Authorization: Bearer $TOKEN\" \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "            -H \"Content-Type: application/json\" \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "            --data '{\"mode\":\"block\",\"configuration\":{\"target\":\"<ip_type>\",\"value\":\"<ip>\"},\"notes\":\"Fail2Ban <name>\"}'" >> /etc/fail2ban/action.d/cloudflare-token.conf
done

echo -n "actionunban = " >> /etc/fail2ban/action.d/cloudflare-token.conf
for (( i=0; i<ZONE_COUNT; i++ )); do
    ZONE="${ZONES[$i]}"
    TOKEN="${TOKENS[$i]}"
    if [ $i -gt 0 ]; then
        echo -n "              " >> /etc/fail2ban/action.d/cloudflare-token.conf
    fi
    echo "id$i=\$(curl -s -X GET \"https://api.cloudflare.com/client/v4/zones/$ZONE/firewall/access_rules/rules?mode=block&configuration_target=<ip_type>&configuration_value=<ip>&match=all\" \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "              -H \"Authorization: Bearer $TOKEN\" \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "              -H \"Content-Type: application/json\" | jq -r '.result[0].id' | grep -v null) && \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "              if [ -n \"\$id$i\" ]; then curl -s -X DELETE \"https://api.cloudflare.com/client/v4/zones/$ZONE/firewall/access_rules/rules/\$id$i\" \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "              -H \"Authorization: Bearer $TOKEN\" \\" >> /etc/fail2ban/action.d/cloudflare-token.conf
    echo "              -H \"Content-Type: application/json\"; fi" >> /etc/fail2ban/action.d/cloudflare-token.conf
done

cat << 'EOF' >> /etc/fail2ban/action.d/cloudflare-token.conf

[Init]
[Init?family=inet6]
ip_type = ip6
[Init?family=inet4]
ip_type = ip
EOF

LOGPATH_LINES="logpath = ${LOG_PATHS[0]}"
for (( i=1; i<${#LOG_PATHS[@]}; i++ )); do
    LOGPATH_LINES="${LOGPATH_LINES}
          ${LOG_PATHS[$i]}"
done

echo "Creating Jail Local Configuration..."
cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
# Ban for 2 hours
bantime = 7200
findtime = 600
maxretry = 5
banaction = cloudflare-token
banaction_allports = cloudflare-token

[nginx-limit-req]
enabled = true
port    = http,https
filter  = nginx-limit-req
$LOGPATH_LINES

[nginx-botsearch]
enabled = true
port    = http,https
maxretry = 2
filter  = nginx-botsearch
$LOGPATH_LINES
EOF

echo "Restarting Fail2Ban and Nginx..."
systemctl reload nginx
systemctl restart fail2ban

echo "Installation Complete! Check status with: sudo fail2ban-client status"
