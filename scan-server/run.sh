#!/usr/bin/with-contenv bashio

ulimit -n 1048576

chmod a+x /usr/bin/get_scan_filename

echo "copying defaults and scan_pre from /opt/sane-scan-pdf to /config/sane-scan-pdf if non-existing"
mkdir -p "/config/sane-scan-pdf"
if [ ! -f "/config/sane-scan-pdf/defaults" ]; then
    mv /opt/sane-scan-pdf/defaults /config/sane-scan-pdf/defaults
else
    rm /opt/sane-scan-pdf/defaults
fi
ln -s /config/sane-scan-pdf/defaults /opt/sane-scan-pdf/defaults

if [ ! -f "/config/sane-scan-pdf/scan_pre" ]; then
    mv /opt/sane-scan-pdf/scan_pre /config/sane-scan-pdf/scan_pre
else
    rm /opt/sane-scan-pdf/scan_pre
fi
ln -s /config/sane-scan-pdf/scan_pre /opt/sane-scan-pdf/scan_pre

chmod a+x /config/sane-scan-pdf/defaults /config/sane-scan-pdf/scan_pre

# copy custom component if it doesn't already exist
if [ ! -d "/homeassistant/custom_components/scan_server_integration" ]; then
    echo "Custom integration not found, copying..."
    mkdir -p /homeassistant/custom_components/scan_server_integration
    cp -r /custom_components/scan_server_integration/* /homeassistant/custom_components/scan_server_integration/
fi

CONFIG_PATH_DLL="/config/dll.conf"
SCANBD_CONF_DLL="/etc/scanbd/dll.conf"

echo "Checking for $CONFIG_PATH_DLL"
if [ ! -f "$CONFIG_PATH_DLL" ]; then
    mv "$SCANBD_CONF_DLL" "$CONFIG_PATH_DLL"
    echo "created default config"
else
    echo "use existing config"
fi
rm -f "$SCANBD_CONF_DLL"
ln -s "$CONFIG_PATH_DLL" "$SCANBD_CONF_DLL"

CONFIG_PATH_SANED="/config/saned.conf"
SANED_CONF="/etc/sane.d/saned.conf"

echo "Checking for $CONFIG_PATH_SANED"
if [ ! -f "$CONFIG_PATH_SANED" ]; then
    echo -e "\n# Allow all private network ranges\nlocalhost\n192.168.0.0/16\n10.0.0.0/8\n172.16.0.0/12" | tee -a "$SANED_CONF"
    mv "$SANED_CONF" "$CONFIG_PATH_SANED"
    echo "created default config"
else
    echo "use existing config"
fi
rm -f "$SANED_CONF"
ln -s "$CONFIG_PATH_SANED" "$SANED_CONF"

CONFIG_PATH_SCANBD="/config/scanbd.conf"
SCANBD_CONF="/etc/scanbd/scanbd.conf"

echo "Checking for $CONFIG_PATH_SCANBD"
if [ ! -f "$CONFIG_PATH_SCANBD" ]; then
    mv "$SCANBD_CONF" "$CONFIG_PATH_SCANBD"
    sed -i 's/"test\.script"/"scan.script"/g' "$CONFIG_PATH_SCANBD"
    echo "created default config"
else
    echo "use existing config"
fi
rm -f "$SCANBD_CONF"
ln -s "$CONFIG_PATH_SCANBD" "$SCANBD_CONF"

SCRIPT_PATH="/config/scripts"
if [ ! -d "$SCRIPT_PATH" ]; then
    echo "creating default scanbd scripts in $SCRIPT_PATH"
    mv /usr/share/scanbd/scripts /config/
else
    echo "Using existing scanbd scripts from $SCRIPT_PATH"
fi

SCAN_SCRIPT="$SCRIPT_PATH/scan.script"
SCAN_SCRIPT_SOURCE="src/scripts/scan.script"
if [ ! -f "$SCAN_SCRIPT" ]; then
    mv "$SCAN_SCRIPT_SOURCE" "$SCRIPT_PATH"
fi
chmod a+x "$SCRIPT_PATH/$(basename "$SCAN_SCRIPT")"
ln -sfn /config/scripts /etc/scanbd/scripts

echo "Starting dbus-daemon..."
dbus-daemon --system

echo "Starting inetd..."
service openbsd-inetd start

# ------------------------------------------------------------
# HP LaserJet M1536dnf diagnostic block
# ------------------------------------------------------------
# This is intentionally diagnostic only. It must never prevent scanbd
# from starting. The M1536dnf exposes its scanner through the HP vendor
# interface (03f0:012a), and HPLIP/hpaio is expected to handle it.

echo ""
echo "========================================"
echo "HP M1536dnf diagnostic"
echo "========================================"

HP_LINE="$(lsusb -d 03f0:012a 2>/dev/null | head -n 1 || true)"
if [ -n "$HP_LINE" ]; then
    echo "HP USB device: $HP_LINE"
    HP_BUS="$(echo "$HP_LINE" | awk '{print $2}')"
    HP_DEV="$(echo "$HP_LINE" | awk '{print $4}' | tr -d ':')"
    HP_USB="/dev/bus/usb/${HP_BUS}/${HP_DEV}"
    echo "USB node: $HP_USB"
    ls -l "$HP_USB" 2>&1 || true
else
    echo "WARNING: HP device 03f0:012a not found"
fi

echo "--- kernel usblp state ---"
grep -E '^usblp ' /proc/modules 2>/dev/null || echo "usblp not loaded"

echo "--- HPLIP packages ---"
dpkg -l 2>/dev/null | grep -E 'hplip|libsane-hpaio|sane-utils' || true

echo "--- HPLIP USB discovery ---"
timeout 15 hp-probe -b usb 2>&1 || true

echo "--- SANE devices ---"
timeout 20 scanimage -L 2>&1 || true

echo "--- sane-find-scanner HP result ---"
timeout 20 sane-find-scanner 2>&1 | grep -E '03f0|Hewlett|HP LaserJet|found possible USB scanner' || true

HP_URI="$(timeout 20 scanimage -L 2>/dev/null | sed -n 's/^device `\([^`]*\)'.*/\1/p' | grep -m1 '^hpaio:/usb/HP_LaserJet_M1536dnf_MFP' || true)"

if [ -n "$HP_URI" ]; then
    echo "Detected HPAIO URI: $HP_URI"
    echo "--- HPAIO open test (diagnostic only) ---"
    SANE_DEBUG_DLL=255 SANE_DEBUG_HPAIO=255 \
        timeout 15 scanimage -d "$HP_URI" --help 2>&1 || true
else
    echo "WARNING: HPAIO URI was not detected by scanimage -L"
fi

echo "========================================"
echo "End HP diagnostic"
echo "========================================"
echo ""

OPTIONS_FILE="/data/options.json"

reload_options() {
    NETSHARE_SERVER=$(jq -r '.netshare_server' "$OPTIONS_FILE")
    NETSHARE_USERNAME=$(jq -r '.netshare_username' "$OPTIONS_FILE")
    NETSHARE_PASSWORD=$(jq -r '.netshare_password' "$OPTIONS_FILE")
    NETSHARE_PATH=$(jq -r '.netshare_path' "$OPTIONS_FILE")
    NETSHARE_PATH="${NETSHARE_PATH##[\\/]}"

    curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
        http://supervisor/mounts/scanserver -X DELETE > /dev/null

    if [[ -n "$NETSHARE_SERVER" ]]; then
        JSON_DATA=$(jq -n \
            --arg name "scanserver" \
            --arg usage "share" \
            --arg type "cifs" \
            --arg server "$NETSHARE_SERVER" \
            --arg share "$NETSHARE_PATH" \
            --arg username "$NETSHARE_USERNAME" \
            --arg password "$NETSHARE_PASSWORD" \
            --argjson read_only false \
            '{
                name: $name,
                usage: $usage,
                type: $type,
                server: $server,
                share: $share,
                username: $username,
                password: $password,
                read_only: $read_only
            }')

        RESPONSE=$(curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
            -H "Content-Type: application/json" \
            -X POST -d "$JSON_DATA" http://supervisor/mounts)
        RESPONSE_RESULT=$(jq -r ".result" <<< "$RESPONSE")

        if [[ $RESPONSE_RESULT != 'ok' ]]; then
            curl -X POST \
                -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{
                    "message": "The network share could not be mounted, please check the host, user, password and path in the add-on options.",
                    "title": "Scan Server Error: Could not mount network share",
                    "notification_id": "scan_server_error"
                }' \
                http://supervisor/core/api/services/persistent_notification/create
        else
            echo "Network share $NETSHARE_SERVER/$NETSHARE_PATH mounted to /share/scanserver"
        fi
    fi
}

reload_options
trap reload_options SIGHUP

echo "Starting scanbd..."
export SANE_CONFIG_DIR=/etc/scanbd/
scanbd -d2 -f -c /etc/scanbd/scanbd.conf
