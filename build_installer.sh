#!/bin/bash

# ============================================================
# MixDesk X – Adelvo Audio Drivers – Installer Builder
# 2.0.1 (06.11.2026): Tabelle im Begrüßungstext ohne feste Hintergründe (Dark Mode).
# 2.0.0 (06.11.2026): Umbenennung MixDeskEQ → MixDesk X, optionales 16-Kanal-Gerät,
# alte MixDeskEQ-Treiber werden bei der Installation entfernt.
#
# Creates a .pkg installer with selectable components.
# The user can click "Customize" in the installer and
# choose which audio buses to install via checkboxes.
#
# Build requirements:
# - Xcode Command Line Tools (xcode-select --install)
# - Git
#
# End users do NOT need Xcode – they only get the .pkg.
#
# Usage: ./build_installer.sh
# ============================================================

set -e

# ── Configuration ─────────────────────────────────────────

# Instances: "Display Name|internal_suffix|channels"
# The first DEFAULT_SELECTED will be pre-selected in the installer.
INSTANCES=(
    "MixDesk X System|system|2"
    "MixDesk X WebRTC|webrtc|2"
    "MixDesk X Mix 3|mix3|2"
    "MixDesk X Mix 4|mix4|2"
    "MixDesk X Mix 5|mix5|2"
    "MixDesk X Mix 6|mix6|2"
    "MixDesk X Mix 7|mix7|2"
    "MixDesk X Mix 8|mix8|2"
    "MixDesk X 16ch|16ch|16"
)

TOTAL_INSTANCES=${#INSTANCES[@]}
DEFAULT_SELECTED=2

# Installer metadata
PKG_IDENTIFIER_BASE="com.adelvo.mixdeskx.bus"
OLD_PKG_IDENTIFIER_BASE="com.adelvo.mixdeskeq.bus"   # 1.x – wird bei Installation entfernt
PKG_VERSION="2.0.1"
PKG_TITLE="MixDesk X – Adelvo Audio Drivers"
INSTALLER_FILENAME="MixDeskX-AudioDrivers-${PKG_VERSION}"

# Signieren + Notarisieren (Zertifikate im Anmelde-Schlüsselbund; Sicherung: SYNC/Büro/adelvo/zertifikate/)
APP_SIGN_ID="Developer ID Application: Mathias Mathias (G539CDL493)"      # für die .driver-Bundles
PKG_SIGN_ID="Developer ID Installer: Mathias Schneider (G539CDL493)"      # für die .pkg
NOTARY_PROFILE="notarytool-profile"

# ── Colors ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Directories ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/_build"
REPO_DIR="${BUILD_DIR}/BlackHole"
OUTPUT_DIR="${SCRIPT_DIR}/installer"
RESOURCES_DIR="${BUILD_DIR}/resources"
HAL_RELATIVE="Library/Audio/Plug-Ins/HAL"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   MixDesk X – Audio Drivers – Installer Builder          ║${NC}"
echo -e "${CYAN}║                                                          ║${NC}"
echo -e "${CYAN}║   Building ${TOTAL_INSTANCES} instances, ${DEFAULT_SELECTED} pre-selected.                ║${NC}"
echo -e "${CYAN}║   User selects components via checkboxes in installer.   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Preflight ─────────────────────────────────────────────
for tool in git xcodebuild pkgbuild productbuild; do
    if ! command -v $tool &>/dev/null; then
        echo -e "${RED}✗ '$tool' not found.${NC}"
        [ "$tool" != "git" ] && echo "  → xcode-select --install"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} $tool"
done

echo ""
echo -e "${BOLD}Building ${TOTAL_INSTANCES} instances:${NC}"
for ((i=0; i<TOTAL_INSTANCES; i++)); do
    IFS='|' read -r name suffix ch <<< "${INSTANCES[$i]}"
    default=""
    [ $((i+1)) -le $DEFAULT_SELECTED ] && default=" ${GREEN}(pre-selected)${NC}"
    echo -e "  🎧 ${name}${default}"
done
echo ""
read -p "Start build? (y/n): " confirm
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && echo "Cancelled." && exit 0

# ── Setup ─────────────────────────────────────────────────
rm -rf "${BUILD_DIR}"
CONFIGS_DIR="${BUILD_DIR}/configs"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}" "${RESOURCES_DIR}" "${CONFIGS_DIR}"

# ── Clone BlackHole ───────────────────────────────────────
echo ""
echo -e "${CYAN}▶ Cloning BlackHole repository...${NC}"
git clone --quiet --depth 1 https://github.com/ExistentialAudio/BlackHole.git "${REPO_DIR}"
echo -e "${GREEN}✓${NC} Repository cloned"

# ── Compile & package instances ───────────────────────────
echo ""
echo -e "${CYAN}▶ Compiling instances...${NC}"

COMPONENT_PKGS=()

for ((i=0; i<TOTAL_INSTANCES; i++)); do
    IFS='|' read -r device_name safe_suffix channels <<< "${INSTANCES[$i]}"
    num=$((i+1))
    bundle_id="${PKG_IDENTIFIER_BASE}.${safe_suffix}"
    driver_filename="MixDeskX_${safe_suffix}.driver"

    echo -e "\n  ${YELLOW}[${num}/${TOTAL_INSTANCES}]${NC} Building \"${device_name}\"..."

    # Config header for this instance (clean way to pass string literals)
    config_header="${CONFIGS_DIR}/config_${safe_suffix}.h"
    cat > "${config_header}" << CONFEOF
#define kDriver_Name "MixDeskX_${safe_suffix}"
#define kDevice_Name "${device_name}"
#define kNumber_Of_Channels ${channels}
#define kHas_Driver_Name_Format 0
#define kPlugIn_BundleID "${bundle_id}"
#define kManufacturer_Name "Adelvo"
CONFEOF

    cd "${REPO_DIR}"
    xcodebuild clean -project BlackHole.xcodeproj -configuration Release &>/dev/null 2>&1 || true
    rm -rf build/

    xcodebuild \
        -project BlackHole.xcodeproj \
        -configuration Release \
        PRODUCT_BUNDLE_IDENTIFIER="${bundle_id}" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        DEVELOPMENT_TEAM="" \
        'OTHER_CFLAGS=$(inherited) -include '"${config_header}" \
        &>/dev/null 2>&1

    built_driver=$(find build/Release -name "*.driver" -maxdepth 1 -type d | head -1)
    if [ -z "$built_driver" ] || [ ! -d "$built_driver" ]; then
        echo -e "  ${RED}✗ Build failed${NC}"
        exit 1
    fi

    # Payload for this instance
    inst_payload="${BUILD_DIR}/payload_${safe_suffix}"
    inst_scripts="${BUILD_DIR}/scripts_${safe_suffix}"
    mkdir -p "${inst_payload}/${HAL_RELATIVE}"
    mkdir -p "${inst_scripts}"

    cp -R "$built_driver" "${inst_payload}/${HAL_RELATIVE}/${driver_filename}"
    # Ohne diese Signatur lehnt Apple die Notarisierung ab ("The binary is not signed", 1.0.0-Lehre 25.09.2026)
    codesign --force --options runtime --timestamp --sign "${APP_SIGN_ID}" "${inst_payload}/${HAL_RELATIVE}/${driver_filename}" 2>/dev/null
    codesign --verify --strict "${inst_payload}/${HAL_RELATIVE}/${driver_filename}" || { echo -e "  ${RED}✗ Signatur des Treibers ungültig${NC}"; exit 1; }

    # Postinstall: restart CoreAudio
    cat > "${inst_scripts}/postinstall" << EOF
#!/bin/bash
killall -9 coreaudiod 2>/dev/null || true
exit 0
EOF
    chmod 755 "${inst_scripts}/postinstall"

    # Build component .pkg
    comp_pkg="${BUILD_DIR}/component_${safe_suffix}.pkg"
    pkgbuild \
        --root "${inst_payload}" \
        --scripts "${inst_scripts}" \
        --identifier "${bundle_id}" \
        --version "${PKG_VERSION}" \
        --install-location "/" \
        "${comp_pkg}" &>/dev/null

    COMPONENT_PKGS+=("${comp_pkg}")
    echo -e "  ${GREEN}✓${NC} \"${device_name}\""
done

# ── Migration: alte MixDeskEQ-Treiber (1.x) entfernen ─────
# Unsichtbare, immer installierte Komponente. Läuft VOR den Bussen (preinstall).
MIG_SCRIPTS="${BUILD_DIR}/scripts_migrate"
mkdir -p "${MIG_SCRIPTS}"
cat > "${MIG_SCRIPTS}/preinstall" << MIGEOF
#!/bin/bash
HAL="/Library/Audio/Plug-Ins/HAL"
rm -rf "\${HAL}"/MixDeskEQ_*.driver 2>/dev/null || true
for id in \$(pkgutil --pkgs | grep '^${OLD_PKG_IDENTIFIER_BASE}'); do pkgutil --forget "\$id" >/dev/null 2>&1 || true; done
exit 0
MIGEOF
chmod 755 "${MIG_SCRIPTS}/preinstall"
pkgbuild --nopayload --scripts "${MIG_SCRIPTS}" --identifier "${PKG_IDENTIFIER_BASE}.migrate" --version "${PKG_VERSION}" "${BUILD_DIR}/component_migrate.pkg" &>/dev/null
echo -e "  ${GREEN}✓${NC} Migration (entfernt MixDeskEQ 1.x)"

# ── Welcome HTML ──────────────────────────────────────────
echo ""
echo -e "${CYAN}▶ Creating installer resources...${NC}"

cat > "${RESOURCES_DIR}/welcome.html" << 'WELCOME_EOF'
<html>
<head><meta charset="utf-8"><meta name="color-scheme" content="light dark"></head>
<body style="font-family: -apple-system, Helvetica Neue, sans-serif; padding: 20px; line-height: 1.6;">
<h2>MixDesk X – Adelvo Audio Drivers</h2>
<p>This installer sets up virtual audio buses that MixDesk X uses
for routing audio between applications.</p>

<p><strong>How it works:</strong></p>
<p>Each bus is an independent stereo audio device (the optional
<em>16ch</em> device has 16 channels, for MixDesk X Pro multichannel routing). Audio sent to a
bus <em>output</em> appears at the <em>input</em> of the same bus
&mdash; like a virtual audio cable.</p>

<p><strong>Example Setup:</strong></p>
<table style="border-collapse: collapse; font-size: 13px; margin: 10px 0;">
<tr>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top; white-space: nowrap;"><strong>System</strong></td>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top;">macOS system audio &rarr; MixDesk X input</td>
</tr>
<tr>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top; white-space: nowrap;"><strong>WebRTC</strong></td>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top;">MixDesk X mix &rarr; Browser / video conferencing</td>
</tr>
<tr>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top; white-space: nowrap;"><strong>Mix 3+</strong></td>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top;">Additional outputs for OBS, recording, etc.</td>
</tr>
<tr>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top; white-space: nowrap;"><strong>16ch</strong></td>
  <td style="padding: 6px 12px; border: 1px solid rgba(128,128,128,0.45); vertical-align: top;">One device, 8 stereo pairs (MixDesk X Pro: pairs 3+4 and up)</td>
</tr>
</table>

<p>Click <strong>&ldquo;Customize&rdquo;</strong> to choose how many
buses to install. 2 buses are sufficient for most setups.</p>

<p><strong>Upgrading from the MixDeskEQ drivers?</strong> The old
&ldquo;MixDeskEQ &hellip;&rdquo; devices are removed and replaced by
&ldquo;MixDesk X &hellip;&rdquo;. Apps that used them (Discord, Zoom, OBS &hellip;)
need the new device selected once.</p>

<p style="opacity: 0.6; font-size: 11px;">Based on BlackHole (GPL-3.0) &middot; MixDesk X by Adelvo</p>
</body>
</html>
WELCOME_EOF

# ── Conclusion HTML ───────────────────────────────────────
cat > "${RESOURCES_DIR}/conclusion.html" << 'CONCLUSION_EOF'
<html>
<head><meta charset="utf-8"><meta name="color-scheme" content="light dark"></head>
<body style="font-family: -apple-system, Helvetica Neue, sans-serif; padding: 20px; line-height: 1.6;">
<h2>Installation Complete</h2>
<p>Your audio buses are now available in:</p>
<ul>
<li><strong>System Settings &rarr; Sound</strong> (selectable as output device)</li>
<li><strong>Audio MIDI Setup</strong> (for verification and configuration)</li>
<li><strong>All audio applications</strong> (as input and output)</li>
<li><strong>MixDesk X</strong> (as routing target)</li>
</ul>
<p>You can assign custom names to buses within MixDesk X
to keep track of which bus is used for what.</p>
<p><strong>Tip:</strong> Open <em>Audio MIDI Setup</em>
(Applications &rarr; Utilities) to verify that all buses
are displayed correctly.</p>
</body>
</html>
CONCLUSION_EOF

echo -e "${GREEN}✓${NC} Welcome & Conclusion created"

# ── Distribution XML ──────────────────────────────────────
echo -e "${CYAN}▶ Assembling distribution package...${NC}"

DIST_XML="${BUILD_DIR}/distribution.xml"

cat > "${DIST_XML}" << DISTHEAD
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>${PKG_TITLE}</title>
    <welcome file="welcome.html"/>
    <conclusion file="conclusion.html"/>
    <options customize="allow" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <choices-outline>
DISTHEAD

echo "        <line choice=\"migrate\"/>" >> "${DIST_XML}"
for ((i=0; i<TOTAL_INSTANCES; i++)); do
    IFS='|' read -r name suffix ch <<< "${INSTANCES[$i]}"
    echo "        <line choice=\"${suffix}\"/>" >> "${DIST_XML}"
done

echo "    </choices-outline>" >> "${DIST_XML}"
cat >> "${DIST_XML}" << DISTMIG
    <choice id="migrate" visible="false" start_selected="true" enabled="false">
        <pkg-ref id="${PKG_IDENTIFIER_BASE}.migrate"/>
    </choice>
    <pkg-ref id="${PKG_IDENTIFIER_BASE}.migrate" version="${PKG_VERSION}">component_migrate.pkg</pkg-ref>
DISTMIG

for ((i=0; i<TOTAL_INSTANCES; i++)); do
    IFS='|' read -r device_name safe_suffix channels <<< "${INSTANCES[$i]}"
    bundle_id="${PKG_IDENTIFIER_BASE}.${safe_suffix}"
    if [ "${channels}" = "2" ]; then devdesc="virtual stereo audio device"; else devdesc="virtual ${channels}-channel audio device (8 stereo pairs; pairs 3+4 and up need MixDesk X Pro)"; fi

    if [ $((i+1)) -le $DEFAULT_SELECTED ]; then
        start_selected="true"
    else
        start_selected="false"
    fi

    cat >> "${DIST_XML}" << DISTCHOICE
    <choice id="${safe_suffix}"
            title="${device_name}"
            description="Installs the ${devdesc} '${device_name}'. Can be used as input and output in all audio applications."
            start_selected="${start_selected}"
            start_enabled="true"
            start_visible="true">
        <pkg-ref id="${bundle_id}"/>
    </choice>
    <pkg-ref id="${bundle_id}" version="${PKG_VERSION}" onConclusion="RequireRestart">component_${safe_suffix}.pkg</pkg-ref>
DISTCHOICE
done

echo "</installer-gui-script>" >> "${DIST_XML}"

productbuild \
    --distribution "${DIST_XML}" \
    --resources "${RESOURCES_DIR}" \
    --package-path "${BUILD_DIR}" \
    "${BUILD_DIR}/${INSTALLER_FILENAME}-unsigned.pkg" &>/dev/null

sign_and_notarize() {   # <unsigniert.pkg> <ziel.pkg>
    productsign --sign "${PKG_SIGN_ID}" --timestamp "$1" "$2" >/dev/null 2>&1 || { echo -e "${RED}✗ productsign fehlgeschlagen${NC}"; exit 1; }
    echo "   notarisieren…"
    xcrun notarytool submit "$2" --keychain-profile "${NOTARY_PROFILE}" --wait 2>&1 | grep -E "status:" | tail -1 | grep -q "Accepted" || { echo -e "${RED}✗ Notarisierung abgelehnt — Protokoll: xcrun notarytool log <id> --keychain-profile ${NOTARY_PROFILE}${NC}"; exit 1; }
    xcrun stapler staple "$2" >/dev/null 2>&1 || { echo -e "${RED}✗ stapler fehlgeschlagen${NC}"; exit 1; }
    spctl -a -t install -vv "$2" 2>&1 | grep -q "Notarized Developer ID" || { echo -e "${RED}✗ Gatekeeper akzeptiert das Paket nicht${NC}"; exit 1; }
}
sign_and_notarize "${BUILD_DIR}/${INSTALLER_FILENAME}-unsigned.pkg" "${OUTPUT_DIR}/${INSTALLER_FILENAME}.pkg"
echo -e "${GREEN}✓${NC} Installer (signiert, notarisiert, gestapelt): ${OUTPUT_DIR}/${INSTALLER_FILENAME}.pkg"

# ── Uninstaller ───────────────────────────────────────────
echo ""
echo -e "${CYAN}▶ Building uninstaller...${NC}"

UNINST_SCRIPTS="${BUILD_DIR}/uninstall_scripts"
mkdir -p "${UNINST_SCRIPTS}"

cat > "${UNINST_SCRIPTS}/postinstall" << UNEOF
#!/bin/bash
HAL="/Library/Audio/Plug-Ins/HAL"
UNEOF

for ((i=0; i<TOTAL_INSTANCES; i++)); do
    IFS='|' read -r name suffix ch <<< "${INSTANCES[$i]}"
    echo "rm -rf \"\${HAL}/MixDeskX_${suffix}.driver\"" >> "${UNINST_SCRIPTS}/postinstall"
done
echo 'rm -rf "${HAL}"/MixDeskEQ_*.driver' >> "${UNINST_SCRIPTS}/postinstall"

cat >> "${UNINST_SCRIPTS}/postinstall" << 'UNEOF2'
killall -9 coreaudiod 2>/dev/null || true
for id in $(pkgutil --pkgs | grep -E 'com\.adelvo\.mixdesk(eq|x)\.bus'); do
    pkgutil --forget "$id" 2>/dev/null || true
done
exit 0
UNEOF2
chmod 755 "${UNINST_SCRIPTS}/postinstall"

mkdir -p "${BUILD_DIR}/uninstall_resources"
cat > "${BUILD_DIR}/uninstall_resources/welcome.html" << 'UNWELCOME'
<html>
<head><meta charset="utf-8"><meta name="color-scheme" content="light dark"></head>
<body style="font-family: -apple-system, Helvetica Neue, sans-serif; padding: 20px; line-height: 1.6;">
<h2>MixDesk X Audio Drivers &mdash; Uninstall</h2>
<p>This will remove <strong>all</strong> MixDesk X audio buses (and old MixDeskEQ buses)
from your system.</p>
<p>After uninstalling, the devices will no longer be available in
System Settings, Audio MIDI Setup, or any other applications.</p>
<p style="color: #c00;"><strong>Please close all audio applications
including MixDesk X before proceeding.</strong></p>
</body>
</html>
UNWELCOME

UNINST_COMP="${BUILD_DIR}/uninstall_component.pkg"
pkgbuild \
    --nopayload \
    --scripts "${UNINST_SCRIPTS}" \
    --identifier "${PKG_IDENTIFIER_BASE}.uninstall" \
    --version "${PKG_VERSION}" \
    "${UNINST_COMP}" &>/dev/null

UNINST_DIST="${BUILD_DIR}/uninstall_distribution.xml"
cat > "${UNINST_DIST}" << UNDIST
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>MixDesk X – Adelvo Audio Drivers – Uninstall</title>
    <welcome file="welcome.html"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <choices-outline>
        <line choice="uninstall"/>
    </choices-outline>
    <choice id="uninstall" visible="false">
        <pkg-ref id="${PKG_IDENTIFIER_BASE}.uninstall"/>
    </choice>
    <pkg-ref id="${PKG_IDENTIFIER_BASE}.uninstall" version="${PKG_VERSION}">uninstall_component.pkg</pkg-ref>
</installer-gui-script>
UNDIST

productbuild \
    --distribution "${UNINST_DIST}" \
    --resources "${BUILD_DIR}/uninstall_resources" \
    --package-path "${BUILD_DIR}" \
    "${BUILD_DIR}/${INSTALLER_FILENAME}-Uninstall-unsigned.pkg" &>/dev/null

sign_and_notarize "${BUILD_DIR}/${INSTALLER_FILENAME}-Uninstall-unsigned.pkg" "${OUTPUT_DIR}/${INSTALLER_FILENAME}-Uninstall.pkg"
echo -e "${GREEN}✓${NC} Uninstaller (signiert, notarisiert, gestapelt): ${OUTPUT_DIR}/${INSTALLER_FILENAME}-Uninstall.pkg"

# ── Cleanup ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}▶ Cleaning up...${NC}"
rm -rf "${BUILD_DIR}"

# ── Done ──────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Build complete! 🎉                                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  📦 ${OUTPUT_DIR}/${INSTALLER_FILENAME}.pkg"
echo "  🗑  ${OUTPUT_DIR}/${INSTALLER_FILENAME}-Uninstall.pkg"
echo ""
echo "  The installer presents to the user:"
echo "    1. Welcome screen with explanation + example setup"
echo "    2. Install type: Standard (System + WebRTC) or Customize"
echo "    3. On \"Customize\": Independent checkboxes for all ${TOTAL_INSTANCES} devices"
echo "    4. Conclusion screen with tips"
echo ""
echo "  Signiert mit ${PKG_SIGN_ID}, notarisiert und gestapelt — direkt verteilbar."
