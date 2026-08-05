#!/usr/bin/with-contenv bashio

set -e

echo "########################################"
echo "### Scan Server starting"
echo "########################################"

chmod +x /usr/bin/get_scan_filename || true

############################################################
# DBUS
############################################################

echo "Starting dbus-daemon..."
mkdir -p /run/dbus
dbus-daemon --system

############################################################
# sane-scan-pdf
############################################################

mkdir -p /config/sane-scan-pdf

[ -f /config/sane-scan-pdf/defaults ] || \
    cp /opt/sane-scan-pdf/defaults /config/sane-scan-pdf/defaults

[ -f /config/sane-scan-pdf/scan_pre ] || \
    cp /opt/sane-scan-pdf/scan_pre /config/sane-scan-pdf/scan_pre

rm -f /opt/sane-scan-pdf/defaults
rm -f /opt/sane-scan-pdf/scan_pre

ln -s /config/sane-scan-pdf/defaults /opt/sane-scan-pdf/defaults
ln -s /config/sane-scan-pdf/scan_pre /opt/sane-scan-pdf/scan_pre

chmod +x /config/sane-scan-pdf/defaults
chmod +x /config/sane-scan-pdf/scan_pre

############################################################
# Config files
############################################################

mkdir -p /config

if [ ! -f /config/dll.conf ]; then
    cp /etc/sane.d/dll.conf /config/dll.conf
fi

rm -f /etc/sane.d/dll.conf
ln -s /config/dll.conf /etc/sane.d/dll.conf

if [ ! -f /config/saned.conf ]; then
cat >/config/saned.conf <<EOF
localhost
127.0.0.1
::1
192.168.0.0/16
10.0.0.0/8
172.16.0.0/12
EOF
fi

rm -f /etc/sane.d/saned.conf
ln -s /config/saned.conf /etc/sane.d/saned.conf

############################################################
# scanbd config
############################################################

if [ ! -f /config/scanbd.conf ]; then
    cp /etc/scanbd/scanbd.conf /config/scanbd.conf
fi

rm -f /etc/scanbd/scanbd.conf
ln -s /config/scanbd.conf /etc/scanbd/scanbd.conf

############################################################
# scripts
############################################################

mkdir -p /config/scripts

if [ ! -f /config/scripts/scan.script ]; then
    cp /src/scripts/scan.script /config/scripts/scan.script
fi

chmod +x /config/scripts/scan.script

rm -rf /etc/scanbd/scripts
ln -s /config/scripts /etc/scanbd/scripts

############################################################
# Home Assistant integration
############################################################

if [ ! -d /homeassistant/custom_components/scan_server_integration ]; then
    mkdir -p /homeassistant/custom_components/scan_server_integration
    cp -r /custom_components/scan_server_integration/* \
        /homeassistant/custom_components/scan_server_integration/
fi

############################################################
# Diagnostics
############################################################

echo "============================"
echo "USB devices"
echo "============================"
lsusb || true

echo "============================"
echo "USB permissions"
echo "============================"

ls -l /dev/bus/usb/001/003 || true

echo "============================"
echo "Processes"
echo "============================"

ps aux

echo "============================"
echo "HP processes"
echo "============================"

pgrep -a hp || true
pgrep -a cups || true
pgrep -a ipp || true
pgrep -a scan || true

echo "============================"
echo "USB device"
echo "============================"

find /dev/bus/usb -type c -exec ls -l {} \;

echo
echo "============================"
echo "Scanner list"
echo "============================"
scanimage -L || true

echo
echo "============================"
echo "HP INFO"
echo "============================"

hp-info -i || true

echo
echo "============================"
echo "HP PROBE"
echo "============================"

hp-probe -b usb || true

echo
echo "============================"
echo "SCANIMAGE DEBUG"
echo "============================"

export SANE_DEBUG_HPAIO=255
export SANE_DEBUG_DLL=255

scanimage \
-d "hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M" \
-T || true

echo
echo "============================"
echo "HPAIO library"
echo "============================"

find /usr -name "libsane-hpaio*" 2>/dev/null || true
find /usr -name "*hpaio*" 2>/dev/null || true

echo
echo "============================"
echo "DLL config"
echo "============================"

cat /etc/sane.d/dll.conf || true

echo
echo "============================"
echo "Installed packages"
echo "============================"

dpkg -l | grep -E "hplip|libsane|sane" || true

echo
echo "============================"
echo "TEST OPEN DEVICE"
echo "============================"

scanimage \
-d "hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M" \
-T || true

echo
echo "============================"
echo "HPLIP diagnostics"
echo "============================"

echo "--- hp-info ---"
which hp-info || true
hp-info --version || true

echo
echo "--- libsane-hpaio ---"
find /usr -name "libsane-hpaio*" 2>/dev/null || true

echo
echo "--- hpaio files ---"
find /usr -name "*hpaio*" 2>/dev/null || true

echo
echo "--- SANE backends ---"
find /usr/lib -name "libsane-*.so*" 2>/dev/null || true

echo
echo "--- Installed packages ---"
dpkg -l | grep -E "hplip|sane|printer-driver" || true

echo
echo "============================"
echo "Find scanner"
echo "============================"
sane-find-scanner || true

############################################################
# saned
############################################################

echo
echo "============================"
echo "Starting saned"
echo "============================"

mkdir -p /var/run/saned

/usr/sbin/saned -a -d128 &

echo
echo "============================"
echo "HPAIO DEBUG"
echo "============================"

export SANE_DEBUG_HPAIO=255
export SANE_DEBUG_DLL=255

scanimage -L || true

echo
echo "Try open scanner..."

hp-info -i || true

echo "============================"
echo "USB permissions"
echo "============================"

ls -l /dev/bus/usb/*/*

echo "============================"
echo "Scan test"
echo "============================"

scanimage -T -d "hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M" || true

scanimage \
-d "hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M" \
--format=pnm >/dev/null || true

echo
echo "============================"
echo "USB devices in container"
echo "============================"

ls -l /dev/bus/usb/*/* || true

echo
echo "============================"
echo "USB printer devices"
echo "============================"

ls -l /dev/usb/* || true

echo
echo "============================"
echo "Loaded kernel modules"
echo "============================"

cat /proc/modules | grep usb || true

echo "============================"
echo "HP INFO"
echo "============================"

hp-info -i || true

echo
echo "============================"
echo "HP PROBE"
echo "============================"

hp-probe -b usb || true

sleep 2

############################################################
# scanbd
############################################################

echo
echo "============================"
echo "Starting scanbd"
echo "============================"

exec scanbd -f -c /etc/scanbd/scanbd.conf
