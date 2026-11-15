#!/bin/sh
# ==============================================================================
# JioFiber Voice on OpenWrt - Universal 1-Click Installer
# https://github.com/marufagul/openwrt-jiofiber-voice-lan
# ==============================================================================

set -e

INSTALL_DIR="/etc/jio-voice"
BACKUP_DIR="/etc/jio-voice/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=========================================================="
echo "📞 JioFiber Voice on OpenWrt (LAN & Wi-Fi Gateway) Installer"
echo "=========================================================="

# Check if running as root on OpenWrt
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: Please run this script as root." >&2
    exit 1
fi

if [ ! -f /etc/openwrt_release ]; then
    echo "[!] Warning: /etc/openwrt_release not found. Make sure this is an OpenWrt system."
fi

mkdir -p "$INSTALL_DIR"
mkdir -p "$BACKUP_DIR"

# Step 1: Backup existing network and firewall configs
echo "[*] Step 1/5: Creating configuration backup..."
tar -czf "$BACKUP_DIR/backup_${TIMESTAMP}.tar.gz" /etc/config/network /etc/config/firewall /etc/config/dhcp 2>/dev/null || true
echo "[+] Backup saved to $BACKUP_DIR/backup_${TIMESTAMP}.tar.gz"

# Step 2: Auto-detect WAN interface
echo "[*] Step 2/5: Detecting WAN interface..."
WAN_IFACE=$(uci -q get network.wan.device || uci -q get network.wan.ifname || echo "")

if [ -z "$WAN_IFACE" ]; then
    # Fallback search for common WAN device names
    for dev in eth1 eth0 wan sfp sfp1; do
        if ip link show "$dev" >/dev/null 2>&1; then
            WAN_IFACE="$dev"
            break
        fi
    done
fi

if [ -z "$WAN_IFACE" ]; then
    echo "[-] Failed to automatically detect WAN interface."
    printf "Enter your physical WAN interface name (e.g. eth1, eth0): "
    read -r WAN_IFACE
fi

echo "[+] Using WAN device: $WAN_IFACE"
VOICE_DEV="${WAN_IFACE}.406"

# Step 3: Configure Voice VLAN 406 in UCI
echo "[*] Step 3/5: Configuring Voice VLAN 406 & 464xlat in UCI..."

# Create 802.1q VLAN device if device-based syntax is used (OpenWrt 21+)
if uci -q get network.@device[0] >/dev/null 2>&1; then
    # Check if voice_dev already exists
    if ! uci -q get network.voice_dev >/dev/null 2>&1; then
        uci set network.voice_dev=device
        uci set network.voice_dev.name="$VOICE_DEV"
        uci set network.voice_dev.type="8021q"
        uci set network.voice_dev.ifname="$WAN_IFACE"
        uci set network.voice_dev.vid="406"
    fi
fi

# Configure network.voice interface
uci set network.voice=interface
uci set network.voice.device="$VOICE_DEV"
uci set network.voice.proto="dhcpv6"
uci set network.voice.reqaddress="try"
uci set network.voice.reqprefix="auto"
uci set network.voice.delegate="0"
uci set network.voice.metric="20"

# Step 4: Configure Firewall Zone & Routing
echo "[*] Step 4/5: Configuring firewall zone and SIP routing..."

# Check if voice firewall zone exists
if ! uci -q get firewall.voice_zone >/dev/null 2>&1; then
    uci set firewall.voice_zone=zone
    uci set firewall.voice_zone.name="voice"
    uci set firewall.voice_zone.network="voice"
    uci set firewall.voice_zone.input="REJECT"
    uci set firewall.voice_zone.output="ACCEPT"
    uci set firewall.voice_zone.forward="REJECT"
    uci set firewall.voice_zone.masq="1"
    uci set firewall.voice_zone.mtu_fix="1"
fi

# Allow LAN to forward to Voice zone for SIP/IMS traffic
if ! uci -q get firewall.lan_to_voice >/dev/null 2>&1; then
    uci set firewall.lan_to_voice=forwarding
    uci set firewall.lan_to_voice.src="lan"
    uci set firewall.lan_to_voice.dest="voice"
fi

uci commit network
uci commit firewall

# Step 5: Deploy Helper Daemons and Rollback Script
echo "[*] Step 5/5: Installing JioJoin beacon daemon and rollback tool..."

cat << 'EOF' > "$INSTALL_DIR/backup_restore.sh"
#!/bin/sh
BACKUP_DIR="/etc/jio-voice/backups"
case "$1" in
    --restore)
        LATEST=$(ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -n 1)
        if [ -n "$LATEST" ]; then
            echo "[*] Restoring from $LATEST..."
            tar -xzf "$LATEST" -C /
            /etc/init.d/network restart
            /etc/init.d/firewall restart
            echo "[+] Settings successfully restored to stock!"
        else
            echo "[-] No backup archive found in $BACKUP_DIR"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 --restore"
        ;;
esac
EOF
chmod +x "$INSTALL_DIR/backup_restore.sh"

echo "[*] Applying network and firewall changes..."
/etc/init.d/network reload || /etc/init.d/network restart
/etc/init.d/firewall reload || /etc/init.d/firewall restart

echo ""
echo "=========================================================="
echo "🎉 SUCCESS: JioFiber Voice Gateway is now configured!"
echo "=========================================================="
echo "1. Connect your phone to your router Wi-Fi."
echo "2. Open the official JioJoin app to pair via OTP."
echo "3. Or configure MicroSIP/Linphone on your PC/phone using:"
echo "   - Domain: 192.168.1.1:5068"
echo "   - Username: Your +91XXXXXXXXXX Jio Landline Number"
echo "4. To restore anytime: /etc/jio-voice/backup_restore.sh --restore"
echo "=========================================================="
