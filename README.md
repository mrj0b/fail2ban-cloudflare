# Fail2Ban + Cloudflare WAF Auto-Installer

This repository contains an automated deployment script that installs Fail2Ban and configures it to securely protect Cloudflare-proxied websites.

### Why this is needed
If you run a standard Fail2Ban installation behind Cloudflare, Fail2Ban will falsely identify Cloudflare's servers as the attackers and ban them via local `iptables`, bringing your entire website offline.

This script configures Fail2Ban to communicate directly with the Cloudflare API (`v4/zones/:zone_id/firewall/access_rules/rules`). When an attacker triggers an Nginx rate limit or bot-search rule, their IP is banned globally at the Cloudflare Edge network for 2 hours.

### Prerequisites

**1. Nginx Cloudflare Real-IP Configuration (CRITICAL)**
If you do not configure Nginx to read the true IP of your visitors, Fail2Ban will ban Cloudflare's servers and take your website offline. You must create an Nginx configuration file containing Cloudflare's IP ranges.

Create a new file on your server at `/etc/nginx/conf.d/cloudflare.conf` and paste the following:

```nginx
# IPv4
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;

# IPv6
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;

real_ip_header CF-Connecting-IP;
```
After saving, restart Nginx: `sudo systemctl restart nginx`

**2. Cloudflare API Token**
You need an API Token with `Zone -> Firewall Services -> Edit` permissions.

**3. Cloudflare Zone ID**
You need the alphanumeric Zone ID from your Cloudflare dashboard overview page.

**4. Nginx Log Paths**
The script will ask for the error log path for each domain so Fail2Ban knows where to monitor for attacks.

### Installation
SSH into your server and run:

```bash
wget https://raw.githubusercontent.com/mrj0b/fail2ban-cloudflare/main/setup.sh
chmod +x setup.sh
sudo ./setup.sh
```

The script will ask you how many Cloudflare zones you want to protect. Then, it will prompt you for the API Token, Zone ID, and Log Path for each domain, and automatically apply the configurations to protect all of them simultaneously.
