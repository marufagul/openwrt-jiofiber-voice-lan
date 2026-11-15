#!/bin/sh
# ==============================================================================
# JioFiber Voice on OpenWrt - Universal 1-Click Installer
# Author: Gul Marufa (@marufagul)
# https://github.com/marufagul/openwrt-jiofiber-voice-lan
# ==============================================================================

set -e

INSTALL_DIR="/etc/jio-voice"
BACKUP_DIR="/etc/jio-voice/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=========================================================="
echo "📞 JioFiber Voice on OpenWrt (LAN & Wi-Fi Gateway) Setup"
echo "   Developed by Gul Marufa (@marufagul)"
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
echo "[*] Step 1/5: Creating configuration snapshot backup..."
tar -czf "$BACKUP_DIR/backup_${TIMESTAMP}.tar.gz" /etc/config/network /etc/config/firewall /etc/config/dhcp 2>/dev/null || true
echo "[+] Safety backup saved to $BACKUP_DIR/backup_${TIMESTAMP}.tar.gz"

# Step 2: Auto-detect WAN interface
echo "[*] Step 2/5: Detecting physical WAN interface..."
WAN_IFACE=$(uci -q get network.wan.device || uci -q get network.wan.ifname || echo "")

if [ -z "$WAN_IFACE" ]; then
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
echo "[*] Step 3/5: Configuring Voice VLAN 406 in UCI network..."

# Create 802.1q VLAN device if device-based syntax is used (OpenWrt 21+)
if uci -q get network.@device[0] >/dev/null 2>&1; then
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

# Step 4: Configure Firewall Zone & Forwarding
echo "[*] Step 4/5: Configuring firewall zone and SIP routing..."

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

# Allow SIP inbound replies
if ! uci -q get firewall.voice_sip_allow >/dev/null 2>&1; then
    uci set firewall.voice_sip_allow=rule
    uci set firewall.voice_sip_allow.name="Allow-Jio-SIP"
    uci set firewall.voice_sip_allow.src="voice"
    uci set firewall.voice_sip_allow.dest="lan"
    uci set firewall.voice_sip_allow.proto="udp tcp"
    uci set firewall.voice_sip_allow.dest_port="5060 5061 5068"
    uci set firewall.voice_sip_allow.target="ACCEPT"
fi

uci commit network
uci commit firewall

# Step 5: Install JioJoin Discovery Beacon & Rollback Utilities
echo "[*] Step 5/5: Installing JioJoin beacon daemon and service..."

ROUTER_IP=$(uci -q get network.lan.ipaddr || echo "192.168.1.1")
MAC_ADDR=$(cat /sys/class/net/br-lan/address 2>/dev/null || cat /sys/class/net/eth0/address 2>/dev/null || echo "00:11:22:33:44:55")
UUID=$(echo "$MAC_ADDR" | tr -d ':' | tr '[:upper:]' '[:lower:]')

# Create UPnP device descriptor
mkdir -p /www
cat <<EOF > /www/jio_desc.xml
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <specVersion>
    <major>1</major>
    <minor>0</minor>
  </specVersion>
  <device>
    <deviceType>urn:schemas-upnp-org:device:InternetGatewayDevice:1</deviceType>
    <friendlyName>JioFiber Home Gateway</friendlyName>
    <manufacturer>Reliance Jio Infocomm Ltd.</manufacturer>
    <manufacturerURL>https://www.jio.com</manufacturerURL>
    <modelDescription>JioFiber High Speed Gateway</modelDescription>
    <modelName>JIDU6401</modelName>
    <modelNumber>JIDU6401-1.0</modelNumber>
    <UDN>uuid:jio-gateway-${UUID}</UDN>
  </device>
</root>
EOF

# Install beacon daemon script
cat << 'EOF' > "$INSTALL_DIR/jio-beacon.sh"
#!/bin/sh
ROUTER_IP=$(uci -q get network.lan.ipaddr || echo "192.168.1.1")
MAC_ADDR=$(cat /sys/class/net/br-lan/address 2>/dev/null || echo "001122334455")
UUID=$(echo "$MAC_ADDR" | tr -d ':' | tr '[:upper:]' '[:lower:]')

while true; do
    if command -v socat >/dev/null 2>&1; then
        printf "HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\nEXT:\r\nLOCATION: http://%s/jio_desc.xml\r\nSERVER: Linux/5.4 UPnP/1.0 JioFiber/JIDU6401-v2.1\r\nST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\nUSN: uuid:jio-gateway-%s::urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n" "$ROUTER_IP" "$UUID" | socat - UDP4-DATAGRAM:239.255.255.250:1900,broadcast 2>/dev/null || true
    fi
    sleep 30
done
EOF
chmod +x "$INSTALL_DIR/jio-beacon.sh"

# Install Procd init service for the beacon
cat << 'EOF' > /etc/init.d/jio-beacon
#!/bin/sh /etc/rc.common
USE_PROCD=1
START=95
STOP=10

start_service() {
    procd_open_instance
    procd_set_param command /etc/jio-voice/jio-beacon.sh
    procd_set_param respawn
    procd_close_instance
}
EOF
chmod +x /etc/init.d/jio-beacon
/etc/init.d/jio-beacon enable 2>/dev/null || true
/etc/init.d/jio-beacon start 2>/dev/null || true

# Install Rollback script
cat << 'EOF' > "$INSTALL_DIR/backup_restore.sh"
#!/bin/sh
BACKUP_DIR="/etc/jio-voice/backups"
case "$1" in
    --restore)
        LATEST=$(ls -t "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | head -n 1)
        if [ -n "$LATEST" ]; then
            echo "[*] Restoring configurations from $LATEST..."
            tar -xzf "$LATEST" -C /
            /etc/init.d/network restart
            /etc/init.d/firewall restart
            echo "[SUCCESS] Configuration reverted to pre-install snapshot."
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

echo "[*] Reloading network and firewall services..."
/etc/init.d/network reload || /etc/init.d/network restart
/etc/init.d/firewall reload || /etc/init.d/firewall restart

echo ""
echo "=========================================================="
echo "🎉 SUCCESS: JioFiber Voice Gateway is ready!"
echo "=========================================================="
echo "1. Connect your smartphone to your OpenWrt Wi-Fi."
echo "2. Open the official JioJoin app -> Tap Configure Device."
echo "   (It will detect your router immediately and prompt for OTP)."
echo "3. Or configure MicroSIP / Linphone using your landline number."
echo "4. Safety Rollback: /etc/jio-voice/backup_restore.sh --restore"
echo "=========================================================="
