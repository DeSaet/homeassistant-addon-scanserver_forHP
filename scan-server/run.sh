#!/usr/bin/with-contenv bashio

set -e

echo "########################################"
echo "### Scan Server starting"
echo "########################################"

chmod +x /usr/bin/get_scan_filename

####################################################
# DBUS
####################################################

echo "Starting dbus-daemon..."

mkdir -p /run/dbus

if [ ! -f /run/dbus/pid ]; then
    dbus-daemon --system
fi

####################################################
# sane-scan-pdf
####################################################

mkdir -p /config/sane-scan-pdf

if [ ! -f /config/sane-scan-pdf/defaults ]; then
    cp /opt/sane-scan-pdf/defaults /config/sane-scan-pdf/defaults
fi

if [ ! -f /config/sane-scan-pdf/scan_pre ]; then
    cp /opt/sane-scan-pdf/scan_pre /config/sane-scan-pdf/scan_pre
fi

ln -sf /config/sane-scan-pdf/defaults /opt/sane-scan-pdf/defaults
ln -sf /config/sane-scan-pdf/scan_pre /opt/sane-scan-pdf/scan_pre

chmod +x /config/sane-scan-pdf/defaults
chmod +x /config/sane-scan-pdf/scan_pre

####################################################
# Home Assistant Integration
####################################################

mkdir -p /homeassistant/custom_components/scan_server_integration

cp -r /custom_components/scan_server_integration/* \
      /homeassistant/custom_components/scan_server_integration/ \
      2>/dev/null || true

####################################################
# Configuration
####################################################

mkdir -p /config/scripts

[ -f /config/dll.conf ] || cp /etc/sane.d/dll.conf /config/dll.conf
[ -f /config/saned.conf ] || cp /etc/sane.d/saned.conf /config/saned.conf
[ -f /config/scanbd.conf ] || cp /etc/scanbd/scanbd.conf /config/scanbd.conf

ln -sf /config/dll.conf /etc/sane.d/dll.conf
ln -sf /config/saned.conf /etc/sane.d/saned.conf
ln -sf /config/scanbd.conf /etc/scanbd/scanbd.conf

####################################################
# scan.script
####################################################

if [ ! -f /config/scripts/scan.script ]; then
    cp /src/scripts/scan.script /config/scripts/scan.script
fi

chmod +x /config/scripts/scan.script

ln -sfn /config/scripts /etc/scanbd/scripts

####################################################
# Diagnostics
####################################################

echo
echo "============================"
echo "USB devices"
echo "============================"

lsusb || true

echo
echo "============================"
echo "Scanner list"
echo "============================"

scanimage -L || true

echo
echo "============================"
echo "SANE backends"
echo "============================"

scanimage -A || true

echo
echo "============================"
echo "Find scanner"
echo "============================"

sane-find-scanner || true

####################################################
# Start saned
####################################################

echo
echo "============================"
echo "Starting saned"
echo "============================"

mkdir -p /var/run/saned

/usr/sbin/saned -l -e &
sleep 2

####################################################
# Network share
####################################################

OPTIONS_FILE="/data/options.json"

reload_options() {

    NETSHARE_SERVER=$(jq -r '.netshare_server' "$OPTIONS_FILE")
    NETSHARE_USERNAME=$(jq -r '.netshare_username' "$OPTIONS_FILE")
    NETSHARE_PASSWORD=$(jq -r '.netshare_password' "$OPTIONS_FILE")
    NETSHARE_PATH=$(jq -r '.netshare_path' "$OPTIONS_FILE")

    NETSHARE_PATH="${NETSHARE_PATH##[\\/]}"

    curl -s \
        -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
        -X DELETE \
        http://supervisor/mounts/scanserver \
        >/dev/null || true

    if [ -n "$NETSHARE_SERVER" ]; then

        JSON=$(jq -n \
            --arg server "$NETSHARE_SERVER" \
            --arg share "$NETSHARE_PATH" \
            --arg username "$NETSHARE_USERNAME" \
            --arg password "$NETSHARE_PASSWORD" \
            '{
                name:"scanserver",
                usage:"share",
                type:"cifs",
                server:$server,
                share:$share,
                username:$username,
                password:$password,
                read_only:false
            }')

        curl \
            -s \
            -H "Authorization: Bearer $SUPERVISOR_TOKEN" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "$JSON" \
            http://supervisor/mounts >/dev/null || true
    fi
}

reload_options

trap reload_options SIGHUP

####################################################
# Start scanbd
####################################################

echo
echo "============================"
echo "Starting scanbd"
echo "============================"

exec scanbd -f -d7 -c /etc/scanbd/scanbd.conf
