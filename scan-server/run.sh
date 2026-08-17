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


# ------------------------------------------------------------
# Custom Home Assistant integration
# ------------------------------------------------------------

if [ ! -d "/homeassistant/custom_components/scan_server_integration" ]; then
    echo "Custom integration not found, copying..."
    mkdir -p /homeassistant/custom_components/scan_server_integration
    cp -r /custom_components/scan_server_integration/* \
        /homeassistant/custom_components/scan_server_integration/
fi


# ------------------------------------------------------------
# SANE configuration
# ------------------------------------------------------------

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
    echo -e "\n# Allow all private network ranges\nlocalhost\n192.168.0.0/16\n10.0.0.0/8\n172.16.0.0/12" \
        | tee -a "$SANED_CONF"

    mv "$SANED_CONF" "$CONFIG_PATH_SANED"
    echo "created default config"
else
    echo "use existing config"
fi

rm -f "$SANED_CONF"
ln -s "$CONFIG_PATH_SANED" "$SANED_CONF"


# ------------------------------------------------------------
# scanbd configuration
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# scanbd scripts
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# D-Bus / inetd
# ------------------------------------------------------------

echo "Starting dbus-daemon..."
dbus-daemon --system

echo "Starting inetd..."
service openbsd-inetd start


# ============================================================
# HP LASERJET M1536dnf DIAGNOSTICS
# ============================================================

echo ""
echo "########################################################"
echo "### HP LaserJet M1536dnf diagnostic mode"
echo "########################################################"


# ------------------------------------------------------------
# USB device
# ------------------------------------------------------------

echo ""
echo "============================"
echo "USB DEVICE"
echo "============================"

HP_LINE="$(lsusb -d 03f0:012a 2>/dev/null | head -n 1 || true)"

if [ -n "$HP_LINE" ]; then

    echo "$HP_LINE"

    HP_BUS="$(echo "$HP_LINE" | awk '{print $2}')"
    HP_DEV="$(echo "$HP_LINE" | awk '{print $4}' | tr -d ':')"
    HP_USB="/dev/bus/usb/${HP_BUS}/${HP_DEV}"

    echo "USB node: $HP_USB"

    ls -l "$HP_USB" 2>&1 || true

else

    echo "ERROR: HP LaserJet M1536dnf not found"

fi


# ------------------------------------------------------------
# Kernel / usblp
# ------------------------------------------------------------

echo ""
echo "============================"
echo "KERNEL USB DRIVER STATE"
echo "============================"

echo "--- usblp ---"

if grep -E '^usblp ' /proc/modules 2>/dev/null; then
    echo "usblp is loaded in the container"
else
    echo "usblp is NOT loaded in the container"
fi

echo ""
echo "--- sysfs drivers ---"

for IFACE in \
    /sys/bus/usb/devices/1-1.3:1.0 \
    /sys/bus/usb/devices/1-1.3:1.1 \
    /sys/bus/usb/devices/1-1.3:1.2 \
    /sys/bus/usb/devices/1-1.3:1.3
do

    if [ -d "$IFACE" ]; then

        echo ""
        echo "Interface: $IFACE"

        if [ -L "$IFACE/driver" ]; then
            readlink "$IFACE/driver"
        else
            echo "Driver: NONE"
        fi

    fi

done


# ------------------------------------------------------------
# HPLIP packages
# ------------------------------------------------------------

echo ""
echo "============================"
echo "HPLIP PACKAGES"
echo "============================"

dpkg -l 2>/dev/null | grep -E \
    'hplip|libsane-hpaio|sane-utils|libsane1' || true


# ------------------------------------------------------------
# HPLIP runtime check
# ------------------------------------------------------------

echo ""
echo "============================"
echo "HPLIP RUNTIME CHECK"
echo "============================"

if command -v hp-check >/dev/null 2>&1; then

    echo "Running hp-check -r..."

    timeout 45 hp-check -r -t 2>&1 || true

else

    echo "hp-check NOT FOUND"

fi


# ------------------------------------------------------------
# HP plugin diagnostics
# ------------------------------------------------------------

echo ""
echo "============================"
echo "HP PROPRIETARY PLUGIN"
echo "============================"

echo "--- hp-plugin ---"

if command -v hp-plugin >/dev/null 2>&1; then
    hp-plugin --help 2>&1 || true
else
    echo "hp-plugin NOT FOUND"
fi

echo ""
echo "--- hp-check-plugin ---"

if command -v hp-check-plugin >/dev/null 2>&1; then
    hp-check-plugin --help 2>&1 || true
else
    echo "hp-check-plugin NOT FOUND"
fi

echo ""
echo "--- possible plugin files ---"

find \
    /usr/share/hplip \
    /usr/lib \
    /var/lib \
    /root/.hplip \
    -type f \
    \( \
        -iname '*plugin*' \
        -o -iname '*hpmud*' \
        -o -iname '*hpipp*' \
    \) \
    2>/dev/null | head -200 || true


# ------------------------------------------------------------
# HPAIO library
# ------------------------------------------------------------

echo ""
echo "============================"
echo "HPAIO LIBRARY"
echo "============================"

HPAIO="/usr/lib/aarch64-linux-gnu/sane/libsane-hpaio.so.1"

if [ -f "$HPAIO" ]; then

    echo "HPAIO: $HPAIO"

    ls -l "$HPAIO"

    echo ""
    echo "--- ldd ---"

    ldd "$HPAIO" 2>&1 || true

else

    echo "ERROR: libsane-hpaio.so.1 NOT FOUND"

fi


# ------------------------------------------------------------
# HPLIP USB discovery
# ------------------------------------------------------------

echo ""
echo "============================"
echo "HPLIP USB DISCOVERY"
echo "============================"

timeout 20 hp-probe -b usb 2>&1 || true


# ------------------------------------------------------------
# SANE configuration
# ------------------------------------------------------------

echo ""
echo "============================"
echo "SANE CONFIGURATION"
echo "============================"

echo "--- /etc/sane.d/dll.conf ---"

cat /etc/sane.d/dll.conf 2>&1 || true

echo ""
echo "--- /etc/sane.d/dll.d ---"

ls -la /etc/sane.d/dll.d 2>&1 || true


# ------------------------------------------------------------
# sane-find-scanner
# ------------------------------------------------------------

echo ""
echo "============================"
echo "SANE USB DETECTION"
echo "============================"

timeout 20 sane-find-scanner 2>&1 \
    | grep -E \
        '03f0|Hewlett|HP LaserJet|found possible USB scanner' \
    || true


# ------------------------------------------------------------
# scanimage -L
# ------------------------------------------------------------

echo ""
echo "============================"
echo "SANE DEVICE LIST"
echo "============================"

SCANIMAGE_OUTPUT="$(timeout 20 scanimage -L 2>&1 || true)"

echo "$SCANIMAGE_OUTPUT"

HP_URI="$(echo "$SCANIMAGE_OUTPUT" \
    | sed -n 's/^device `\([^`]*\)'.*/\1/p' \
    | grep -m1 '^hpaio:/usb/HP_LaserJet_M1536dnf_MFP' || true)"


# ------------------------------------------------------------
# HPAIO OPEN TEST
# ------------------------------------------------------------

echo ""
echo "============================"
echo "HPAIO OPEN TEST"
echo "============================"

if [ -n "$HP_URI" ]; then

    echo "Detected HPAIO URI:"
    echo "$HP_URI"

    echo ""
    echo "Trying SANE device open..."
    echo "IMPORTANT: this is NOT a real scan."

    SANE_DEBUG_DLL=255 \
    SANE_DEBUG_HPAIO=255 \
    timeout 20 \
        scanimage -d "$HP_URI" --help 2>&1 || true

else

    echo "ERROR: HPAIO URI was not detected"

fi


# ------------------------------------------------------------
# Direct HP USB diagnostic through Python/libusb
# ------------------------------------------------------------

echo ""
echo "============================"
echo "LIBUSB DIRECT TEST"
echo "============================"

python3 <<'PY'
try:
    import usb.core

    dev = usb.core.find(idVendor=0x03f0, idProduct=0x012a)

    if dev is None:
        print("LIBUSB: HP device NOT FOUND")
    else:
        print("LIBUSB: HP device FOUND")
        print("Bus:", dev.bus)
        print("Address:", dev.address)

        try:
            print("Manufacturer:", dev.manufacturer)
        except Exception as e:
            print("Manufacturer: ERROR:", e)

        try:
            print("Product:", dev.product)
        except Exception as e:
            print("Product: ERROR:", e)

        try:
            print(
                "Active configuration:",
                dev.get_active_configuration().bConfigurationValue
            )
        except Exception as e:
            print("Configuration: ERROR:", e)

except Exception as e:
    print("LIBUSB TEST ERROR:", repr(e))
PY


# ------------------------------------------------------------
# FINAL STATUS
# ------------------------------------------------------------

echo ""
echo "########################################################"
echo "### HP diagnostic finished"
echo "########################################################"

echo ""
echo "IMPORTANT:"
echo "The diagnostic deliberately does NOT perform a real scan."
echo "If the log reaches this point, the container remains alive."
echo ""


# ============================================================
# NORMAL SCAN SERVER LOGIC
# ============================================================

OPTIONS_FILE="/data/options.json"

reload_options() {

    NETSHARE_SERVER=$(jq -r '.netshare_server' "$OPTIONS_FILE")
    NETSHARE_USERNAME=$(jq -r '.netshare_username' "$OPTIONS_FILE")
    NETSHARE_PASSWORD=$(jq -r '.netshare_password' "$OPTIONS_FILE")
    NETSHARE_PATH=$(jq -r '.netshare_path' "$OPTIONS_FILE")

    NETSHARE_PATH="${NETSHARE_PATH##[\\/]}"

    curl -sSL \
        -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
        http://supervisor/mounts/scanserver \
        -X DELETE > /dev/null

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

        RESPONSE=$(curl -sSL \
            -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$JSON_DATA" \
            http://supervisor/mounts)

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


echo ""
echo "============================"
echo "Starting scanbd"
echo "============================"

export SANE_CONFIG_DIR=/etc/scanbd/

scanbd -d2 -f -c /etc/scanbd/scanbd.conf
