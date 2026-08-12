#!/usr/bin/with-contenv bashio
set +e

echo "########################################"
echo "### Scan Server starting"
echo "########################################"

###############################################################################
# DBUS
###############################################################################

echo
echo "============================"
echo "STARTING DBUS"
echo "============================"

mkdir -p /run/dbus

if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
    dbus-daemon --system --fork 2>&1 || true
fi

sleep 2


###############################################################################
# USB DEVICE LIST
###############################################################################

echo
echo "============================"
echo "USB DEVICES"
echo "============================"

if command -v lsusb >/dev/null 2>&1; then
    lsusb
else
    echo "WARNING: lsusb not found"
fi


###############################################################################
# FIND HP
###############################################################################

echo
echo "============================"
echo "SEARCHING FOR HP 03F0:012A"
echo "============================"

HP_BUS=""
HP_DEVICE=""
HP_DEV=""
HP_SYSDEV=""

if command -v lsusb >/dev/null 2>&1; then

    HP_LINE="$(lsusb | grep -i '03f0:012a' | head -n 1)"

    if [ -n "$HP_LINE" ]; then

        echo "Found:"
        echo "$HP_LINE"

        HP_BUS="$(echo "$HP_LINE" | awk '{print $2}')"
        HP_DEVICE="$(echo "$HP_LINE" | awk '{print $4}' | tr -d ':')"

        HP_DEV="/dev/bus/usb/${HP_BUS}/${HP_DEVICE}"

        echo "Bus:       $HP_BUS"
        echo "Device:    $HP_DEVICE"
        echo "USB node:  $HP_DEV"

    else

        echo "ERROR: HP 03f0:012a not found"

    fi

fi


###############################################################################
# FIND REAL SYSFS PATH
###############################################################################

echo
echo "============================"
echo "HP SYSFS DEVICE"
echo "============================"

for DEV in /sys/bus/usb/devices/*; do

    [ -f "$DEV/idVendor" ] || continue
    [ -f "$DEV/idProduct" ] || continue

    VID="$(cat "$DEV/idVendor" 2>/dev/null)"
    PID="$(cat "$DEV/idProduct" 2>/dev/null)"

    if [ "$VID" = "03f0" ] && [ "$PID" = "012a" ]; then

        HP_SYSDEV="$DEV"
        break

    fi

done

if [ -n "$HP_SYSDEV" ]; then

    echo "HP sysfs path:"
    echo "$HP_SYSDEV"

    echo
    echo "Device attributes:"

    for ATTR in \
        busnum \
        devnum \
        idVendor \
        idProduct \
        manufacturer \
        product \
        serial \
        authorized
    do

        if [ -f "$HP_SYSDEV/$ATTR" ]; then
            echo -n "$ATTR: "
            cat "$HP_SYSDEV/$ATTR"
        fi

    done

else

    echo "ERROR: HP sysfs device not found"

fi


###############################################################################
# DETAILED USB DESCRIPTORS
###############################################################################

echo
echo "============================"
echo "USB DESCRIPTORS"
echo "============================"

if command -v lsusb >/dev/null 2>&1; then

    lsusb -v -d 03f0:012a 2>&1 || true

else

    echo "lsusb not available"

fi


###############################################################################
# USB DEVICE NODE
###############################################################################

echo
echo "============================"
echo "HP USB DEVICE NODE"
echo "============================"

if [ -n "$HP_DEV" ]; then

    if [ -e "$HP_DEV" ]; then

        ls -l "$HP_DEV"

        echo
        echo "fuser:"

        if command -v fuser >/dev/null 2>&1; then
            fuser -v "$HP_DEV" 2>&1 || true
        else
            echo "fuser not installed"
        fi

        echo
        echo "Attempting chmod 666..."

        chmod 666 "$HP_DEV" 2>&1 || true

        echo
        echo "After chmod:"

        ls -l "$HP_DEV"

    else

        echo "ERROR: device node does not exist:"
        echo "$HP_DEV"

    fi

fi


###############################################################################
# USB INTERFACES
###############################################################################

echo
echo "============================"
echo "HP USB INTERFACES"
echo "============================"

if [ -n "$HP_SYSDEV" ]; then

    for IFACE_PATH in "${HP_SYSDEV}":1.*; do

        [ -d "$IFACE_PATH" ] || continue

        echo
        echo "----------------------------------------"
        echo "Interface: $(basename "$IFACE_PATH")"
        echo "----------------------------------------"

        for ATTR in \
            bInterfaceNumber \
            bAlternateSetting \
            bNumEndpoints \
            bInterfaceClass \
            bInterfaceSubClass \
            bInterfaceProtocol \
            authorized \
            interface \
            modalias
        do

            if [ -f "$IFACE_PATH/$ATTR" ]; then
                echo -n "$ATTR: "
                cat "$IFACE_PATH/$ATTR"
            fi

        done

        if [ -L "$IFACE_PATH/driver" ]; then

            echo -n "driver: "
            readlink "$IFACE_PATH/driver"

        else

            echo "driver: NONE"

        fi

        echo
        echo "Endpoints:"

        for EP in "$IFACE_PATH"/ep_*; do

            [ -d "$EP" ] || continue

            echo "  $(basename "$EP")"

            for ATTR in \
                bEndpointAddress \
                bmAttributes \
                wMaxPacketSize \
                bInterval
            do

                if [ -f "$EP/$ATTR" ]; then
                    echo -n "    $ATTR: "
                    cat "$EP/$ATTR"
                fi
            done

        done

    done

fi


###############################################################################
# CHECK USB AUTHORIZATION
###############################################################################

echo
echo "============================"
echo "USB AUTHORIZATION"
echo "============================"

if [ -n "$HP_SYSDEV" ]; then

    if [ -f "$HP_SYSDEV/authorized" ]; then

        echo -n "Device authorized: "
        cat "$HP_SYSDEV/authorized"

        if [ "$(cat "$HP_SYSDEV/authorized")" != "1" ]; then

            echo "Attempting to authorize device..."

            echo 1 > "$HP_SYSDEV/authorized" 2>&1 || true

            echo -n "After attempt: "
            cat "$HP_SYSDEV/authorized"

        fi

    fi

    for IFACE_PATH in "${HP_SYSDEV}":1.*; do

        [ -d "$IFACE_PATH" ] || continue

        if [ -f "$IFACE_PATH/authorized" ]; then

            echo -n "$(basename "$IFACE_PATH") authorized: "
            cat "$IFACE_PATH/authorized"

        fi

    done

fi


###############################################################################
# KERNEL MODULES
###############################################################################

echo
echo "============================"
echo "KERNEL USB MODULES"
echo "============================"

if command -v lsmod >/dev/null 2>&1; then

    lsmod | grep -E 'usblp|usb' || true

fi


###############################################################################
# CHECK USBLP
###############################################################################

echo
echo "============================"
echo "CHECKING USBLP"
echo "============================"

USBLP_FOUND=0

if [ -n "$HP_SYSDEV" ]; then

    for IFACE_PATH in "${HP_SYSDEV}":1.*; do

        [ -d "$IFACE_PATH" ] || continue

        IFACE_NAME="$(basename "$IFACE_PATH")"

        if [ -L "$IFACE_PATH/driver" ]; then

            DRIVER_NAME="$(basename "$(readlink "$IFACE_PATH/driver")")"

            echo "$IFACE_NAME -> $DRIVER_NAME"

            if [ "$DRIVER_NAME" = "usblp" ]; then

                USBLP_FOUND=1

                echo "Attempting to unbind usblp..."

                DRIVER_UNBIND="$(dirname "$(readlink -f "$IFACE_PATH/driver")")/unbind"

                if [ -w "$DRIVER_UNBIND" ]; then

                    echo -n "$IFACE_NAME" > "$DRIVER_UNBIND" 2>&1

                    echo "Unbind command executed."

                else

                    echo "Cannot write to:"
                    echo "$DRIVER_UNBIND"

                fi

            fi

        else

            echo "$IFACE_NAME -> no kernel driver"

        fi

    done

fi

if [ "$USBLP_FOUND" -eq 0 ]; then
    echo "usblp is not attached to any HP interface."
fi


###############################################################################
# CURRENT USER
###############################################################################

echo
echo "============================"
echo "CURRENT USER"
echo "============================"

id

echo
echo "Groups:"

id -nG 2>&1 || true


###############################################################################
# HPLIP
###############################################################################

echo
echo "============================"
echo "HPLIP USB PROBE"
echo "============================"

if command -v hp-probe >/dev/null 2>&1; then

    hp-probe -b usb 2>&1 || true

else

    echo "hp-probe not found"

fi


###############################################################################
# SANE CONFIG
###############################################################################

echo
echo "============================"
echo "SANE CONFIGURATION"
echo "============================"

echo "--- /etc/sane.d/dll.conf ---"

if [ -f /etc/sane.d/dll.conf ]; then
    cat /etc/sane.d/dll.conf
else
    echo "NOT FOUND"
fi

echo
echo "--- /etc/sane.d/dll.d ---"

ls -la /etc/sane.d/dll.d 2>&1 || true


###############################################################################
# SANE FIND SCANNER
###############################################################################

echo
echo "============================"
echo "SANE FIND SCANNER"
echo "============================"

if command -v sane-find-scanner >/dev/null 2>&1; then

    sane-find-scanner -v 2>&1 || true

else

    echo "sane-find-scanner not found"

fi


###############################################################################
# SANE DEVICE LIST
###############################################################################

echo
echo "============================"
echo "SCANIMAGE -L"
echo "============================"

if command -v scanimage >/dev/null 2>&1; then

    export SANE_DEBUG_DLL=128
    export SANE_DEBUG_HPAIO=255

    scanimage -L 2>&1 || true

else

    echo "scanimage not found"

fi


###############################################################################
# DIRECT OPEN TEST
###############################################################################

echo
echo "============================"
echo "DIRECT HP SCANNER OPEN TEST"
echo "============================"

HP_SCANNER="hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M"

echo "Device:"
echo "$HP_SCANNER"

if command -v scanimage >/dev/null 2>&1; then

    echo
    echo "--- get-device-descriptors ---"

    scanimage \
        --device-name="$HP_SCANNER" \
        --get-device-descriptors \
        2>&1 || true

    echo
    echo "--- test scan parameters ---"

    scanimage \
        --device-name="$HP_SCANNER" \
        --format=pnm \
        --resolution 75 \
        --mode Gray \
        --source Flatbed \
        --progress \
        > /tmp/hp-test-scan.pnm 2>/tmp/hp-test-scan.log

    SCAN_RESULT=$?

    echo "Scan exit code: $SCAN_RESULT"

    echo
    echo "--- stderr ---"

    cat /tmp/hp-test-scan.log 2>/dev/null || true

    if [ -f /tmp/hp-test-scan.pnm ]; then

        echo
        echo "--- output file ---"

        ls -lh /tmp/hp-test-scan.pnm

    fi

fi


###############################################################################
# START SANED
###############################################################################

echo
echo "============================"
echo "STARTING SANED"
echo "============================"

if command -v saned >/dev/null 2>&1; then

    if [ -f /etc/services ]; then

        grep -q '^sane-streamtcp' /etc/services 2>/dev/null || \
            echo "sane-streamtcp 6566/tcp" >> /etc/services

    fi

    echo "Starting saned..."

    saned -d -l 2>&1 &

    SANED_PID=$!

    sleep 2

    echo "saned PID: $SANED_PID"

    if kill -0 "$SANED_PID" 2>/dev/null; then
        echo "saned is running"
    else
        echo "WARNING: saned process exited"
    fi

else

    echo "ERROR: saned not found"

fi


###############################################################################
# FINAL SANE CHECK
###############################################################################

echo
echo "============================"
echo "FINAL SANE CHECK"
echo "============================"

if command -v scanimage >/dev/null 2>&1; then

    scanimage -L 2>&1 || true

fi


###############################################################################
# FINAL USB STATUS
###############################################################################

echo
echo "============================"
echo "FINAL USB STATUS"
echo "============================"

if command -v lsusb >/dev/null 2>&1; then
    lsusb
fi

if [ -n "$HP_DEV" ]; then

    echo
    echo "HP device node:"

    ls -l "$HP_DEV" 2>&1 || true

fi

if [ -n "$HP_SYSDEV" ]; then

    echo
    echo "HP sysfs path:"
    echo "$HP_SYSDEV"

    echo
    echo "Drivers after tests:"

    for IFACE_PATH in "${HP_SYSDEV}":1.*; do

        [ -d "$IFACE_PATH" ] || continue

        echo -n "$(basename "$IFACE_PATH"): "

        if [ -L "$IFACE_PATH/driver" ]; then
            readlink "$IFACE_PATH/driver"
        else
            echo "NONE"
        fi

    done

fi


echo
echo "########################################"
echo "### Scan Server running"
echo "########################################"


###############################################################################
# KEEP ADD-ON ALIVE
###############################################################################

while true; do
    sleep 3600
done
