# 🔍 JioJoin App & Jio IMS Voice Authentication Architecture

This technical document details how the official **JioJoin** mobile app interacts with JioFiber gateways, why SSDP discovery alone is only the first phase, and how the end-to-end SIP IMS authentication handshake functions.

---

## The Two-Phase Authentication Lifecycle

```
  ┌───────────────────────┐                    ┌─────────────────────────┐
  │   JIOJOIN MOBILE APP  │                    │   OPENWRT HOME ROUTER   │
  └───────────┬───────────┘                    └────────────┬────────────┘
              │                                             │
   PHASE 1:   │ --- 1. M-SEARCH * (SSDP Multicast 1900) --> │
   DISCOVERY  │ <--- 2. NOTIFY (http://192.168.1.1/jio_desc) - │ (Handled by jio-beacon.sh)
              │ --- 3. GET /jio_desc.xml (UPnP Specs) ----> │
              │                                             │
   ───────────┼─────────────────────────────────────────────┼────────────────────────────
              │                                             │
   PHASE 2:   │ --- 4. User Enters Mobile Number & OTP ---> │ (Requires hgw-voice-app)
   IMS SIP    │ <--- 5. Local REST API Response (Port 80/8080) │
   REGISTRATION│ --- 6. SIP REGISTER (TLS / Port 5068) ----> │
              │ <--- 7. 200 OK (SIP Session Established) -- │
```

### Phase 1: SSDP Network Beaconing (Included in this Repo)
When you connect your phone to Wi-Fi and open the JioJoin app, it sends an SSDP multicast query to `239.255.255.250:1900`. 
Our daemon (`jio-beacon.sh`) answers this query and continuously announces the router's presence using `/www/jio_desc.xml`.
- **Result:** The JioJoin app displays: *"JioFiber Gateway Found"*.

### Phase 2: Local Gateway Voice Daemon & OTP Verification
After discovery, the JioJoin app attempts to authenticate with the router. In stock Jio firmware, this is handled by a proprietary userspace daemon named **`hgw-voice-app`** (developed by Sercomm / Juice):
1. **TR-069 IMS Credentials:** The router stores an encrypted configuration file at `/etc/juice/FixedVoiceCcsXML.dat` containing the subscriber's IMS private identity (`IMPI`), public identity (`IMPU`), and P-CSCF realm.
2. **Local B2BUA Listener:** `hgw-voice-app` listens on local port `5068` (SIP over TLS).
3. **OTP Handshake:** The JioJoin app talks to this local daemon to verify the OTP against Jio's IMS core.

> [!WARNING]
> **Why SSDP Beaconing Alone Cannot Complete Phone Pairing:**  
> Clean OpenWrt does not ship with proprietary Reliance Jio/Sercomm binaries. If your router does not run `hgw-voice-app` or an equivalent SIP proxy, the JioJoin app will discover the gateway in Phase 1, but will **time out when entering the OTP in Phase 2**.

---

## How to Deploy `hgw-voice-app` on OpenWrt (From Stock Firmware Dump)

If you have extracted the stock root filesystem (SquashFS dump) from your router before flashing OpenWrt, you can run the original voice daemon natively on OpenWrt:

### 1. Required Files from Stock SquashFS:
* `/root/juice_bundle.tar.gz` (contains `/tmp/juice/hgw-voice-app`, `libims`, `ont_dc`, and `libnossl.so`)
* `/etc/juice/FixedVoiceCcsXML.dat` (contains your landline provisioning token)

### 2. Populate Stock Device Identifiers on Boot:
Create a startup script `/root/jio_startup.sh`:
```sh
#!/bin/sh
# Populate hardware identification required by hgw-voice-app
echo "JIDU6401" > /tmp/deviceModel
echo "RSVHGHKW0079194" > /tmp/deviceSerial
echo "SRCMJIO_JIDU6401_R2.0.9" > /tmp/firmVersion
echo "IDU" > /tmp/productType
echo "9c:d4:a6:c9:c0:5a" > /tmp/wanMAC
mkdir -p /tmp/cpe3
echo "JIDU6401" > /tmp/cpe3/dps.productclass

# Unpack juice bundle if missing
if [ ! -d /tmp/juice ]; then
    tar -xzf /root/juice_bundle.tar.gz -C /tmp/
fi

# Launch voice supervisor
/etc/init.d/hgw-voice restart
```

### 3. Alternative: Global PBX via Asterisk (Repo 2)
If you do not want to run stock binaries on your router, use our companion project [jiofiber-asterisk-global-pbx](https://github.com/marufagul/jiofiber-asterisk-global-pbx). It connects Asterisk running on a cloud VPS directly to your home voice trunk, giving you worldwide calling via standard SIP apps (MicroSIP / Linphone).
