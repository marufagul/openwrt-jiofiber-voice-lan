# 📱 Softphone & SIP Configuration Guide

This guide walks through configuring third-party SIP clients (MicroSIP, Linphone, Grandstream desk phones) to register with Reliance Jio's IMS Core directly over your OpenWrt router.

---

## 🔑 Required Credentials

JioFiber / Jio AirFiber voice accounts use credentials derived from your landline number and IMS circle domain:

1. **Jio Fixed Line Number**: Format `+91<STD_CODE><NUMBER>` (e.g. `+9122XXXXXXXX` or `+9180XXXXXXXX`).
2. **SIP Username / Authentication ID**: `+91<STD_CODE><NUMBER>@ims.mnc861.mcc405.3gppnetwork.org`
3. **Domain / Realm**: `ims.mnc861.mcc405.3gppnetwork.org` (MNC 861 is Jio's national code; MCC 405 is India).
4. **SIP Outbound Proxy (P-CSCF)**: Received automatically via DHCPv6 SIP option 21 on interface `ethX.406` or discovered via DNS SRV `_sip._udp.ims.mnc861.mcc405.3gppnetwork.org`.
5. **SIP Port**: UDP `5060` or `5068`.

> [!TIP]
> To find your active P-CSCF IP address on OpenWrt, run:
> ```bash
> logread | grep -i p-cscf
> # or query via the voice interface:
> nslookup _sip._udp.ims.mnc861.mcc405.3gppnetwork.org $(uci get network.voice.ip6addr | cut -d/ -f1)
> ```

---

## 💻 MicroSIP Setup (Windows)

1. Download and install [MicroSIP](https://www.microsip.org/).
2. Click the top-right down arrow ▾ and select **Add Account...**
3. Configure the following fields:
   - **Account Name**: `Jio Landline`
   - **SIP Server**: `ims.mnc861.mcc405.3gppnetwork.org`
   - **SIP Proxy**: `[<YOUR_PCSCF_IPV6_OR_CLAT_IPV4>]:5060`
   - **User**: `+91<YOUR_NUMBER>`
   - **Domain**: `ims.mnc861.mcc405.3gppnetwork.org`
   - **Login**: `+91<YOUR_NUMBER>`
   - **Password**: *(Leave blank if using AKA/IP-based authentication on Voice VLAN, or enter your device SIP token if extracted)*
4. Under **Media / Codecs**:
   - Check **G.711 A-law (PCMA)** and **G.711 u-law (PCMU)**. Jio IMS strongly prefers PCMA (8kHz).
   - Enable **AMR / AMR-WB** if HD Voice is desired.
5. Click **Save**. The status indicator in the bottom bar will transition to **Online**.

---

## 📱 Linphone Setup (Android / iOS / Linux)

1. Download **Linphone** from Google Play, App Store, or your distribution repository.
2. Select **USE A SIP ACCOUNT**.
3. Fill in details:
   - **Username**: `+91<YOUR_NUMBER>`
   - **SIP Domain**: `ims.mnc861.mcc405.3gppnetwork.org`
   - **Transport**: `UDP`
   - **Outbound Proxy**: `sip:[<YOUR_PCSCF_ADDRESS>]:5060;transport=udp`
4. Under **Settings > Audio**:
   - Priority 1: `PCMA`
   - Priority 2: `PCMU`
   - Priority 3: `G729` (if licensed)
5. Save and verify registration.

---

## ☎️ Hardware VoIP Desk Phone (Grandstream, Yealink)

1. Access the web administrative console of your VoIP phone.
2. Navigate to **Account 1 > General Settings**:
   - **Account Active**: Yes
   - **Account Name**: Jio Voice
   - **SIP Server**: `ims.mnc861.mcc405.3gppnetwork.org`
   - **Outbound Proxy**: `<P-CSCF_IP>`
   - **SIP User ID**: `+91<YOUR_NUMBER>`
   - **Authenticate ID**: `+91<YOUR_NUMBER>`
3. Navigate to **Account 1 > SIP Settings > Basic Settings**:
   - **SIP Registration**: Yes
   - **Register Expiration**: 600 seconds
   - **Local SIP Port**: 5060
4. Under **Audio Settings / Codecs**:
   - Set Codec 1 to `PCMA (G.711a)`.
5. Apply and reboot the phone.
