# Fail2Ban + Cloudflare WAF Auto-Installer

This repository contains an automated deployment script that installs Fail2Ban and configures it to securely protect Cloudflare-proxied websites.

### Why this is needed
If you run a standard Fail2Ban installation behind Cloudflare, Fail2Ban will falsely identify Cloudflare's servers as the attackers and ban them via local `iptables`, bringing your entire website offline.

This script configures Fail2Ban to communicate directly with the Cloudflare API (`v4/zones/:zone_id/firewall/access_rules/rules`). When an attacker triggers an Nginx rate limit or bot-search rule, their IP is banned globally at the Cloudflare Edge network for 2 hours.

### Prerequisites
1. You must have **Nginx** configured to log the real IP of your visitors (using `set_real_ip_from` and `real_ip_header CF-Connecting-IP;`).
2. You need a **Cloudflare API Token** with `Zone -> Firewall Services -> Edit` permissions.
3. You need your **Cloudflare Zone ID**.

### Installation
SSH into your server and run:

```bash
wget https://raw.githubusercontent.com/mrj0b/fail2ban-cloudflare/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

The script will prompt you for your API Token and Zone ID, and automatically apply the configurations.
