# 🛠️ Manual SSH Configuration Guide: JioFiber Voice Gateway

This guide provides **100% manual SSH commands** to configure OpenWrt for Jio voice routing. Every command can be typed directly into an SSH terminal without automation scripts or AI.

---

## Step 1: FTTH (VLAN 406) vs AirFiber 5G (VLAN 1015)

* **JioFiber FTTH (Optical Fiber GPON):** Voice runs on dedicated 802.1Q tagged **VLAN 406**.
* **Jio AirFiber 5G (Outdoor Unit):** Voice runs inside the 5G data bearer on **VLAN 1015**.

---

## Step 2: Configure Voice Interface via UCI

```bash
# 1. Create VLAN 406 Device (Replace 'wan' with your physical WAN port)
uci set network.voice_dev=device
uci set network.voice_dev.name='wan.406'
uci set network.voice_dev.type='8021q'
uci set network.voice_dev.ifname='wan'
uci set network.voice_dev.vid='406'

# 2. Configure network.voice interface (DHCPv6 client)
uci set network.voice=interface
uci set network.voice.device='wan.406'
uci set network.voice.proto='dhcpv6'
uci set network.voice.reqaddress='try'
uci set network.voice.reqprefix='auto'
uci set network.voice.delegate='0'
uci set network.voice.metric='20'

uci commit network
/etc/init.d/network restart
```

---

## Step 3: Configure Voice Firewall Zone & Forwarding

```bash
# 1. Create Voice Firewall Zone
uci set firewall.voice_zone=zone
uci set firewall.voice_zone.name='voice'
uci set firewall.voice_zone.network='voice'
uci set firewall.voice_zone.input='REJECT'
uci set firewall.voice_zone.output='ACCEPT'
uci set firewall.voice_zone.forward='REJECT'
uci set firewall.voice_zone.masq='1'
uci set firewall.voice_zone.masq6='1'
uci set firewall.voice_zone.mtu_fix='1'

# 2. Allow LAN to forward to Voice zone for SIP/IMS traffic
uci set firewall.lan_to_voice=forwarding
uci set firewall.lan_to_voice.src='lan'
uci set firewall.lan_to_voice.dest='voice'

# 3. Allow inbound SIP replies from Jio IMS
uci set firewall.voice_sip_allow=rule
uci set firewall.voice_sip_allow.name='Allow-Jio-SIP'
uci set firewall.voice_sip_allow.src='voice'
uci set firewall.voice_sip_allow.dest='lan'
uci set firewall.voice_sip_allow.proto='udp tcp'
uci set firewall.voice_sip_allow.dest_port='5060 5061 5068'
uci set firewall.voice_sip_allow.target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

---

## Step 4: Disable Kernel SIP ALG (Eliminates One-Way Audio)

OpenWrt's kernel SIP helper often rewrites internal SDP IP addresses incorrectly, causing silent or one-way audio calls:

```bash
mkdir -p /etc/modules.d
cat << 'EOF' > /etc/modules.d/99-blacklist-sip
blacklist nf_nat_sip
blacklist nf_conntrack_sip
EOF
rmmod nf_nat_sip nf_conntrack_sip 2>/dev/null || true
```

---

## Step 5: Add nftables Voice QoS DSCP Tagging

Tag SIP signaling with `CS5` (priority) and voice RTP audio packets with `EF` (Expedited Forwarding):

```bash
mkdir -p /etc/nftables.d
cat << 'EOF' > /etc/nftables.d/40-jio-voice.nft
table inet jio_voice_qos {
    chain mangle_prerouting {
        type filter hook prerouting priority mangle; policy accept;
        ip protocol udp udp dport { 5060, 5061, 5068 } ip dscp set cs5
        ip protocol tcp tcp dport { 5060, 5061, 5068 } ip dscp set cs5
        ip6 nexthdr udp udp dport { 5060, 5061, 5068 } ip6 dscp set cs5
        ip6 nexthdr tcp tcp dport { 5060, 5061, 5068 } ip6 dscp set cs5
        ip protocol udp udp dport 10000-20000 ip dscp set ef
        ip6 nexthdr udp udp dport 10000-20000 ip6 dscp set ef
    }
}
EOF

/etc/init.d/firewall restart
```
