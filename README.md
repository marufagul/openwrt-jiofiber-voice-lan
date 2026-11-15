# 📞 JioFiber Voice on OpenWrt (LAN & Wi-Fi Gateway)

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-23.05%20%7C%2024.10%20%7C%20Master-00a8e8?logo=openwrt&logoColor=white)](https://openwrt.org)
[![Tested Hardware](https://img.shields.io/badge/Hardware-MT7986%20%7C%20x86%20%7C%20GL.iNet-brightgreen)](#hardware-compatibility)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**Ditch the locked JioFiber router. Keep your home landline number running on your own high-performance OpenWrt router over Wi-Fi.**

[Quick Start](#-quick-start) • [How It Works](#-how-it-works) • [JioJoin App](#-using-jiojoin-app) • [SIP Softphone](#-using-standard-sip-phones) • [FAQ](#-frequently-asked-questions)

</div>

---

> [!TIP]
> **Using an AI Coding Assistant? (Claude Code, Gemini CLI, Cursor, Windsurf)**  
> Copy and paste this prompt directly into your agent terminal to auto-configure your router:  
> ```text
> "Connect to my OpenWrt router at 192.168.1.1 via SSH. Inspect the WAN physical interface, backup existing network/firewall UCI configs to /tmp/jio_backup.tar.gz, clone https://github.com/marufagul/openwrt-jiofiber-voice-lan, run ./install.sh in non-interactive mode for Voice VLAN 406, and verify that the Jio voice interface receives an IP address."
> ```

---

## ⚡ Quick Start (1-Line Install)

SSH into your OpenWrt router and run:

```bash
wget -O - https://raw.githubusercontent.com/marufagul/openwrt-jiofiber-voice-lan/main/install.sh | sh
```

The script will:
1. 🛡️ **Create a full safety backup** of your router's network and firewall configuration.
2. 🔍 **Detect your WAN interface** (ONT Ethernet / SFP / MediaTek Filogic ODU).
3. 🌐 **Provision Voice VLAN 406** with dual-stack IPv6/IPv4 464xlat clat.
4. 📱 **Enable the JioJoin beacon**, allowing the official JioJoin app to ring on Wi-Fi.

To restore stock settings at any time:
```bash
/etc/jio-voice/backup_restore.sh --restore
```

---

## 📊 Stock Jio Router vs. OpenWrt Voice Gateway

| Feature | Stock Locked Jio Router | OpenWrt Voice Gateway |
| :--- | :---: | :---: |
| **Wi-Fi 6/7 Performance** | ❌ Heavily throttled / basic | ✅ Full Filogic MT7986 / Custom AP speeds |
| **Custom DNS (AdGuard / Pi-hole)** | ❌ Blocked by Jio TR-069 | ✅ Full DoH / DoT / Ad-blocking |
| **Official JioJoin App on Phone** | ✅ Works on Wi-Fi | ✅ Works on Wi-Fi |
| **Standard SIP Softphones (MicroSIP)** | ❌ Blocked | ✅ Fully Supported |
| **Hardware VoIP Desk Phones** | ❌ Not allowed | ✅ Supported via local SIP proxy |
| **Zero Server / Zero Cloud Cost** | ✅ Included | ✅ 100% Free & Local |

---

## 🛠️ How It Works

```
 ┌─────────────────────────────────────────────────────────────┐
 │                      HOME WI-FI NETWORK                     │
 │                                                             │
 │   [Smartphone with JioJoin]     [PC with MicroSIP/Linphone] │
 │              │                              │               │
 │              ▼                              ▼               │
 │       192.168.1.x:Wi-Fi              192.168.1.x:Ethernet   │
 └──────────────────────┬──────────────────────┬───────────────┘
                        │                      │
 ┌──────────────────────▼──────────────────────▼───────────────┐
 │                   YOUR OPENWRT ROUTER                       │
 │                                                             │
 │   • mDNS Beacon Emulator (Ports 8080/5068)                  │
 │   • nftables Transparent Voice Routing                      │
 │   • Dedicated Voice Interface: eth0.406 (VLAN 406)          │
 └──────────────────────────────┬──────────────────────────────┘
                                │
                    464xlat / IPv6 IMS Slice
                                │
 ┌──────────────────────────────▼──────────────────────────────┐
 │              RELIANCE JIO IMS CORE NETWORK                  │
 │              (P-CSCF / Call State Control)                  │
 └─────────────────────────────────────────────────────────────┘
```

---

## 📱 Using Official JioJoin App

1. Connect your smartphone to your OpenWrt Wi-Fi network.
2. Open the **JioJoin** app (available on Google Play / Apple App Store).
3. Tap **Configure JioFiber Device**. The app will detect your OpenWrt router automatically via our multicast beacon daemon.
4. Enter the OTP sent to your registered Jio mobile number.
5. Your home landline is now live on your smartphone!

---

## 💻 Using Standard SIP Softphones (MicroSIP / Linphone / Zoiper)

If you prefer not to use the JioJoin app and want a lightweight softphone on Windows, Mac, Linux, or iOS:
- Open **MicroSIP** (Windows) or **Linphone** (Android/iOS).
- Add Account:
  - **SIP Server:** `192.168.1.1:5068`
  - **User:** Your Jio landline number (`+91XXXXXXXXXX`)
  - **Transport:** UDP / TCP
- Detailed instructions in [docs/SOFTPHONE_SETUP_GUIDE.md](docs/SOFTPHONE_SETUP_GUIDE.md).

---

## 🛡️ Safety & Reversibility

We believe in non-destructive, safe tooling:
- **No optical tampering:** Does not alter your GPON/EPON ONT registration or PLOAM password.
- **Instant Rollback:** Run `/etc/jio-voice/backup_restore.sh --restore` to wipe all voice settings and restore your exact prior network state in seconds.

---

## 🤝 Community & Support

- 💬 Join the discussion on **[BroadbandForum.co Community Thread](https://broadbandforum.co)**
- 🐛 Found a bug or tested on a new router? [Open an Issue](https://github.com/marufagul/openwrt-jiofiber-voice-lan/issues)
- ⭐ **Star this repository** if it helped you break free from locked ISP hardware!
