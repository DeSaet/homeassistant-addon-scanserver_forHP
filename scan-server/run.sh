#!/usr/bin/with-contenv bashio
set +e

echo "########################################"
echo "### Scan Server starting"
echo "########################################"

echo
echo "============================"
echo "Starting dbus-daemon"
echo "============================"

mkdir -p /run/dbus

if [ ! -f /run/dbus/pid ]; then
    dbus-daemon --system --fork
fi

sleep 2


echo
echo "============================"
echo "USB DEVICES - HOST VIEW"
echo "============================"

if command -v lsusb >/dev/null 2>&1; then
    lsusb
else
    echo "WARNING: lsusb not found"
fi


echo
echo "============================"
echo "SEARCHING FOR HP M1536dnf"
echo "============================"

HP_BUS=""
HP_DEVICE=""
HP_SYSDEV=""

if command -v lsusb >/dev/null 2>&1; then

    HP_LINE="$(lsusb | grep -i '03f0:012a' | head -n 1)"

    if [ -n "$HP_LINE" ]; then
        echo "HP USB device:"
        echo "$HP_LINE"

        HP_BUS="$(echo "$HP_LINE" | awk '{print $2}')"
        HP_DEVICE="$(echo "$HP_LINE" | awk '{print $4}' | tr -d ':')"

        echo "USB bus:    $HP_BUS"
        echo "USB device: $HP_DEVICE"

        HP_SYSDEV="/sys/bus/usb/devices/1-1.3"

    else
        echo "WARNING: HP LaserJet M1536dnf was not found by lsusb"
    fi
fi


echo
echo "============================"
echo "USB SYSFS"
echo "============================"

if [ -d "$HP_SYSDEV" ]; then

    echo "HP sysfs device: $HP_SYSDEV"

    echo
    echo "Interfaces:"

    for IFACE in 0 1 2 3; do

        IFACE_PATH="${HP_SYSDEV}:1.${IFACE}"

        if [ -d "$IFACE_PATH" ]; then

            echo "----- interface $IFACE -----"

            if [ -f "$IFACE_PATH/bInterfaceNumber" ]; then
                echo -n "number:   "
                cat "$IFACE_PATH/bInterfaceNumber"
            fi

            if [ -f "$IFACE_PATH/bInterfaceClass" ]; then
                echo -n "class:    "
                cat "$IFACE_PATH/bInterfaceClass"
            fi

            if [ -f "$IFACE_PATH/bInterfaceSubClass" ]; then
                echo -n "subclass: "
                cat "$IFACE_PATH/bInterfaceSubClass"
            fi

            if [ -f "$IFACE_PATH/bInterfaceProtocol" ]; then
                echo -n "protocol: "
                cat "$IFACE_PATH/bInterfaceProtocol"
            fi

            if [ -L "$IFACE_PATH/driver" ]; then
                echo -n "driver:   "
                readlink "$IFACE_PATH/driver"
            else
                echo "driver:   NONE"
            fi

        fi

    done

else

    echo "HP sysfs device not available inside container"

fi


echo
echo "============================"
echo "DISABLING USBLP FOR HP"
echo "============================"

#
# HP M1536 has:
#
# interface 0 = HP scanner/control interface
# interface 1 = USB printer interface
#
# usblp attaches to interface 1.
#
# HPLIP uses libusb and may need to detach usblp.
#

USBLP_UNBOUND=0

for SYSROOT in \
    /sys/bus/usb/devices \
    /sys/devices
do

    if [ -d "$SYSROOT" ]; then

        for IFACE_PATH in \
            "$SYSROOT"/1-1.3:1.1 \
            "$SYSROOT"/*/1-1.3:1.1
        do

            if [ -d "$IFACE_PATH" ]; then

                echo "Found HP printer interface:"
                echo "$IFACE_PATH"

                if [ -L "$IFACE_PATH/driver" ]; then

                    DRIVER="$(basename "$(readlink "$IFACE_PATH/driver")")"

                    echo "Current driver: $DRIVER"

                    if [ "$DRIVER" = "usblp" ]; then

                        echo "Attempting to unbind usblp..."

                        if [ -w "$IFACE_PATH/driver/unbind" ]; then

                            echo -n "1-1.3:1.1" > "$IFACE_PATH/driver/unbind" 2>/tmp/usblp_unbind_error

                            if [ $? -eq 0 ]; then
                                echo "SUCCESS: usblp unbound"
                                USBLP_UNBOUND=1
                            else
                                echo "WARNING: unable to unbind usblp"
                                cat /tmp/usblp_unbind_error
                            fi

                        else

                            echo "WARNING: driver/unbind is not writable"

                        fi

                    else

                        echo "usblp is not attached"

                    fi

                else

                    echo "No driver attached to interface"

                fi

            fi

        done

    fi

done


if [ "$USBLP_UNBOUND" -eq 0 ]; then
    echo
    echo "WARNING:"
    echo "usblp could not be detached from inside the container."
    echo "Continuing anyway."
    echo
fi


echo
echo "============================"
echo "USB DEVICES AFTER USBLP"
echo "============================"

if command -v lsusb >/dev/null 2>&1; then
    lsusb
fi


echo
echo "============================"
echo "USB DEVICE PERMISSIONS"
echo "============================"

if [ -n "$HP_BUS" ] && [ -n "$HP_DEVICE" ]; then

    HP_DEV="/dev/bus/usb/$HP_BUS/$HP_DEVICE"

    echo "Expected HP device:"
    echo "$HP_DEV"

    if [ -e "$HP_DEV" ]; then

        ls -l "$HP_DEV"

        echo "Setting permissions..."

        chmod 666 "$HP_DEV" 2>/dev/null

        chown root:scanner "$HP_DEV" 2>/dev/null

        ls -l "$HP_DEV"

    else

        echo "WARNING: HP device node does not exist"

    fi

fi


echo
echo "============================"
echo "CURRENT USER"
echo "============================"

id


echo
echo "============================"
echo "GROUPS"
echo "============================"

cat /etc/group | grep -E '^(root|lp|plugdev|scanner|lpadmin):'


echo
echo "============================"
echo "LOADED KERNEL MODULES"
echo "============================"

if command -v lsmod >/dev/null 2>&1; then
    lsmod | grep -E 'usblp|usb' || true
fi


echo
echo "============================"
echo "SANE VERSION"
echo "============================"

if command -v scanimage >/dev/null 2>&1; then
    scanimage --version
else
    echo "ERROR: scanimage not found"
fi


echo
echo "============================"
echo "SANE BACKENDS"
echo "============================"

if [ -f /etc/sane.d/dll.conf ]; then

    echo "Enabled SANE backends:"
    grep -v '^[[:space:]]*#' /etc/sane.d/dll.conf | grep -v '^[[:space:]]*$'

fi


echo
echo "============================"
echo "SANE FIND SCANNER"
echo "============================"

if command -v sane-find-scanner >/dev/null 2>&1; then

    sane-find-scanner -v || true

else

    echo "WARNING: sane-find-scanner not found"

fi


echo
echo "============================"
echo "SCANIMAGE -L"
echo "============================"

if command -v scanimage >/dev/null 2>&1; then

    export SANE_DEBUG_DLL="${SANE_DEBUG_DLL:-0}"
    export SANE_DEBUG_HPAIO="${SANE_DEBUG_HPAIO:-0}"

    scanimage -L || true

else

    echo "ERROR: scanimage not found"

fi


echo
echo "============================"
echo "HP SANE DEVICE DIRECT TEST"
echo "============================"

if command -v scanimage >/dev/null 2>&1; then

    HP_SCANNER="hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M"

    echo "Testing:"
    echo "$HP_SCANNER"

    scanimage -L 2>&1 || true

fi


echo
echo "============================"
echo "SANED CONFIGURATION"
echo "============================"

if [ -f /etc/sane.d/saned.conf ]; then
    cat /etc/sane.d/saned.conf
else
    echo "/etc/sane.d/saned.conf not found"
fi


echo
echo "============================"
echo "STARTING SANED"
echo "============================"

if command -v saned >/dev/null 2>&1; then

    echo "saned found:"
    command -v saned

else

    echo "WARNING: saned not found"

fi


echo
echo "============================"
echo "STARTING SCAN SERVICES"
echo "============================"

#
# Do not start hp-info or hp-toolbox here.
# They can disturb the USB interface of some HPLIP devices.
#

if command -v saned >/dev/null 2>&1; then

    if [ -f /etc/services ]; then

        grep -q '^sane-streamtcp' /etc/services 2>/dev/null || \
            echo "sane-streamtcp 6566/tcp" >> /etc/services

    fi

    echo "Starting saned..."

    saned -d -l 2>&1 &

    SANED_PID=$!

    echo "saned PID: $SANED_PID"

else

    echo "saned cannot be started"

fi


echo
echo "============================"
echo "FINAL USB STATUS"
echo "============================"

if command -v lsusb >/dev/null 2>&1; then
    lsusb
fi

if [ -n "$HP_BUS" ] && [ -n "$HP_DEVICE" ]; then

    HP_DEV="/dev/bus/usb/$HP_BUS/$HP_DEVICE"

    echo
    echo "HP device:"
    ls -l "$HP_DEV" 2>/dev/null || true

fi


echo
echo "########################################"
echo "### Scan Server running"
echo "########################################"


#
# Keep the add-on alive.
#

while true; do

    sleep 3600

done
