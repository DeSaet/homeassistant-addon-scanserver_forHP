#!/usr/bin/with-contenv bashio
set -u

echo "########################################"
echo "### Scan Server starting"
echo "########################################"

echo ""
echo "============================"
echo "Starting dbus-daemon"
echo "============================"
mkdir -p /run/dbus
dbus-daemon --system --fork || true

echo ""
echo "============================"
echo "USB devices"
echo "============================"
lsusb || true

echo ""
echo "============================"
echo "Finding HP LaserJet M1536dnf"
echo "============================"

HP_LINE="$(lsusb -d 03f0:012a 2>/dev/null | head -n 1 || true)"

if [ -z "$HP_LINE" ]; then
    echo "ERROR: HP device 03f0:012a was not found!"
    exit 1
fi

echo "$HP_LINE"

HP_BUS="$(echo "$HP_LINE" | awk '{print $2}')"
HP_DEV="$(echo "$HP_LINE" | awk '{print $4}' | tr -d ':')"

HP_USB="/dev/bus/usb/${HP_BUS}/${HP_DEV}"

echo ""
echo "Detected:"
echo "  Bus:    $HP_BUS"
echo "  Device: $HP_DEV"
echo "  Path:   $HP_USB"

echo ""
echo "============================"
echo "USB device permissions"
echo "============================"
ls -l "$HP_USB" 2>&1 || true
stat "$HP_USB" 2>&1 || true

echo ""
echo "============================"
echo "Current user"
echo "============================"
id || true

echo ""
echo "============================"
echo "Relevant groups"
echo "============================"
getent group lp 2>/dev/null || true
getent group scanner 2>/dev/null || true
getent group plugdev 2>/dev/null || true

echo ""
echo "============================"
echo "USB descriptor"
echo "============================"
timeout 10 lsusb -v -d 03f0:012a 2>&1 || true

echo ""
echo "============================"
echo "Finding sysfs device"
echo "============================"

SYS_DEVICE=""

for d in /sys/bus/usb/devices/*; do
    [ -f "$d/idVendor" ] || continue

    VID="$(cat "$d/idVendor" 2>/dev/null || true)"
    PID="$(cat "$d/idProduct" 2>/dev/null || true)"

    if [ "$VID" = "03f0" ] && [ "$PID" = "012a" ]; then
        SYS_DEVICE="$d"
        break
    fi
done

if [ -z "$SYS_DEVICE" ]; then
    echo "ERROR: HP device was not found in /sys/bus/usb/devices"
else
    echo "SYS_DEVICE=$SYS_DEVICE"

    echo ""
    echo "--- Device information ---"

    for f in \
        idVendor \
        idProduct \
        manufacturer \
        product \
        serial \
        busnum \
        devnum \
        speed \
        bNumConfigurations \
        bConfigurationValue \
        authorized
    do
        if [ -f "$SYS_DEVICE/$f" ]; then
            echo -n "$f: "
            cat "$SYS_DEVICE/$f" 2>/dev/null || true
        fi
    done

    echo ""
    echo "============================"
    echo "USB interfaces"
    echo "============================"

    for i in "${SYS_DEVICE}":*; do
        [ -d "$i" ] || continue

        echo "----------------------------"
        echo "Interface path: $i"

        echo -n "Interface number: "
        cat "$i/bInterfaceNumber" 2>/dev/null || true

        echo -n "Class: "
        cat "$i/bInterfaceClass" 2>/dev/null || true

        echo -n "Subclass: "
        cat "$i/bInterfaceSubClass" 2>/dev/null || true

        echo -n "Protocol: "
        cat "$i/bInterfaceProtocol" 2>/dev/null || true

        echo -n "Endpoints: "
        cat "$i/bNumEndpoints" 2>/dev/null || true

        echo -n "Driver: "
        if [ -L "$i/driver" ]; then
            readlink "$i/driver" 2>/dev/null || true
        else
            echo "NONE"
        fi

        for e in "$i"/ep_*; do
            [ -e "$e" ] || continue

            echo "  Endpoint: $(basename "$e")"

            echo -n "    Address: "
            cat "$e/bEndpointAddress" 2>/dev/null || true

            echo -n "    Attributes: "
            cat "$e/bmAttributes" 2>/dev/null || true

            echo -n "    Max packet: "
            cat "$e/wMaxPacketSize" 2>/dev/null || true

            echo -n "    Type: "
            cat "$e/type" 2>/dev/null || true
        done
    done
fi

echo ""
echo "============================"
echo "Kernel modules"
echo "============================"
grep -E 'usblp|usbcore|xhci|dwc2' /proc/modules 2>/dev/null || true

echo ""
echo "============================"
echo "HPLIP versions"
echo "============================"
dpkg -l 2>/dev/null | grep -E 'hplip|libsane-hpaio|sane-utils' || true

echo ""
echo "============================"
echo "HPLIP device discovery"
echo "============================"

timeout 15 hp-probe -b usb 2>&1 || true

echo ""
echo "============================"
echo "SANE configuration"
echo "============================"

echo "--- /etc/sane.d/dll.conf ---"
cat /etc/sane.d/dll.conf 2>&1 || true

echo ""
echo "--- /etc/sane.d/dll.d ---"
find /etc/sane.d/dll.d -maxdepth 1 -type f -print -exec cat {} \; 2>&1 || true

echo ""
echo "============================"
echo "Scanner detection"
echo "============================"

timeout 20 sane-find-scanner -v 2>&1 || true

echo ""
echo "--- scanimage -L ---"
timeout 20 scanimage -L 2>&1 || true

HP_URI="hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M"

echo ""
echo "============================"
echo "HPAIO OPEN TEST"
echo "============================"
echo "Device: $HP_URI"
echo "Timeout: 15 seconds"
echo ""

SANE_DEBUG_DLL=255 \
SANE_DEBUG_HPAIO=255 \
timeout 15 scanimage -d "$HP_URI" --help 2>&1 || true

echo ""
echo "============================"
echo "HPAIO REAL SCAN TEST"
echo "============================"
echo "Timeout: 30 seconds"
echo ""

rm -f /tmp/hp-test.pnm

SANE_DEBUG_DLL=255 \
SANE_DEBUG_HPAIO=255 \
timeout 30 scanimage \
    -d "$HP_URI" \
    --format=pnm \
    --resolution 75 \
    > /tmp/hp-test.pnm 2>&1

SCAN_RC=$?

echo ""
echo "Scan command exit code: $SCAN_RC"

if [ -f /tmp/hp-test.pnm ]; then
    echo "Scan output exists:"
    ls -lh /tmp/hp-test.pnm
else
    echo "No scan output file created"
fi

echo ""
echo "============================"
echo "Final USB state"
echo "============================"

lsusb -d 03f0:012a 2>&1 || true
ls -l "$HP_USB" 2>&1 || true

echo ""
echo "============================"
echo "DONE"
echo "============================"

echo ""
echo "Diagnostics finished."

exit 0
