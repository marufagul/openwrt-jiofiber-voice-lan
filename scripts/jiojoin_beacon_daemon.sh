#!/bin/sh
# ==============================================================================
# JioJoin Discovery Beacon Daemon
# Emulates Jio ONT SSDP/UPnP device discovery on LAN so the official JioJoin app
# automatically detects the OpenWrt router as a legitimate JioFiber Gateway.
# ==============================================================================

SSDP_ADDR="239.255.255.250"
SSDP_PORT=1900
ROUTER_IP=$(uci -q get network.lan.ipaddr || echo "192.168.1.1")
MAC_ADDR=$(cat /sys/class/net/br-lan/address 2>/dev/null || cat /sys/class/net/eth0/address 2>/dev/null || echo "00:11:22:33:44:55")
UUID=$(echo "$MAC_ADDR" | tr -d ':' | tr '[:upper:]' '[:lower:]')

echo "[*] Starting JioJoin Discovery Beacon Daemon on $ROUTER_IP..."
echo "[+] Virtual Device UUID: jio-gateway-${UUID}"

# Check for socat or nc
if command -v socat >/dev/null 2>&1; then
    DISCOVERY_ENGINE="socat"
elif command -v nc >/dev/null 2>&1; then
    DISCOVERY_ENGINE="nc"
else
    echo "[!] Neither socat nor netcat found. Attempting opkg install..."
    opkg update >/dev/null 2>&1 || true
    opkg install socat >/dev/null 2>&1 || true
    if command -v socat >/dev/null 2>&1; then
        DISCOVERY_ENGINE="socat"
    else
        DISCOVERY_ENGINE="none"
    fi
fi

# Create standard UPnP XML descriptor in /www so uhttpd serves it
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
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:WANIPConnection:1</serviceType>
        <serviceId>urn:upnp-org:serviceId:WANIPConn1</serviceId>
        <controlURL>/upnp/control/WANIPConn1</controlURL>
        <eventSubURL>/upnp/event/WANIPConn1</eventSubURL>
        <SCPDURL>/gateconnSCPD.xml</SCPDURL>
      </service>
    </serviceList>
  </device>
</root>
EOF

echo "[+] Jio device descriptor published to http://${ROUTER_IP}/jio_desc.xml"

# Periodic SSDP broadcast loop using printf for 100% POSIX / BusyBox compatibility
while true; do
    if [ "$DISCOVERY_ENGINE" = "socat" ]; then
        printf "HTTP/1.1 200 OK\r\nCACHE-CONTROL: max-age=1800\r\nEXT:\r\nLOCATION: http://%s/jio_desc.xml\r\nSERVER: Linux/5.4 UPnP/1.0 JioFiber/JIDU6401-v2.1\r\nST: urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\nUSN: uuid:jio-gateway-%s::urn:schemas-upnp-org:device:InternetGatewayDevice:1\r\n\r\n" "$ROUTER_IP" "$UUID" | socat - UDP4-DATAGRAM:239.255.255.250:1900,broadcast 2>/dev/null || true
    fi
    sleep 30
done
