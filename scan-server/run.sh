#!/bin/bash

echo "########################################"
echo "### Scan Server diagnostic run.sh"
echo "########################################"

echo "============================"
echo "SYSTEM"
echo "============================"
uname -a 2>&1
id 2>&1

echo "============================"
echo "USB DEVICES"
echo "============================"
lsusb 2>&1

echo "============================"
echo "USB PERMISSIONS"
echo "============================"
ls -l /dev/bus/usb/*/* 2>&1

echo "============================"
echo "HP USB DEVICE"
echo "============================"
for d in /sys/bus/usb/devices/*; do
  [ -f "$d/idVendor" ] || continue

  if [ "$(cat "$d/idVendor" 2>/dev/null)" = "03f0" ] && \
     [ "$(cat "$d/idProduct" 2>/dev/null)" = "012a" ]; then

    echo "HP DEVICE: $d"
    echo -n "Vendor: "
    cat "$d/idVendor" 2>/dev/null
    echo -n "Product: "
    cat "$d/idProduct" 2>/dev/null
    echo -n "Manufacturer: "
    cat "$d/manufacturer" 2>/dev/null
    echo -n "Product name: "
    cat "$d/product" 2>/dev/null
    echo -n "Serial: "
    cat "$d/serial" 2>/dev/null
  fi
done

echo "============================"
echo "HP USB INTERFACES"
echo "============================"

for i in /sys/bus/usb/devices/1-1.3:1.*; do
  [ -d "$i" ] || continue

  echo "=============================="
  echo "INTERFACE: $i"

  echo -n "Number:   "
  cat "$i/bInterfaceNumber" 2>/dev/null

  echo -n "Class:    "
  cat "$i/bInterfaceClass" 2>/dev/null

  echo -n "Subclass: "
  cat "$i/bInterfaceSubClass" 2>/dev/null

  echo -n "Protocol: "
  cat "$i/bInterfaceProtocol" 2>/dev/null

  echo -n "Driver:   "
  readlink "$i/driver" 2>/dev/null || echo "NONE"

  echo -n "Endpoints: "
  cat "$i/bNumEndpoints" 2>/dev/null

  for e in "$i"/ep_*; do
    [ -e "$e" ] || continue

    echo -n "  "
    basename "$e"

    echo -n "    maxpacket: "
    cat "$e/wMaxPacketSize" 2>/dev/null

    echo -n "    type: "
    cat "$e/type" 2>/dev/null
  done
done

echo "============================"
echo "HPLIP VERSION"
echo "============================"

hp-info --version 2>&1 || true

dpkg -l 2>/dev/null | grep -E 'hplip|libsane|sane' || true

echo "============================"
echo "SANE CONFIG"
echo "============================"

echo "--- /etc/sane.d/dll.conf ---"
cat /etc/sane.d/dll.conf 2>&1

echo "--- /etc/sane.d/dll.d/hplip ---"
cat /etc/sane.d/dll.d/hplip 2>&1

echo "============================"
echo "SANE DEVICES"
echo "============================"

SANE_DEBUG_DLL=255 \
SANE_DEBUG_HPAIO=255 \
scanimage -L 2>&1

echo "============================"
echo "HP PROBE"
echo "============================"

hp-probe -b usb -c 1 2>&1 || true

echo "============================"
echo "HPLIP SCAN PLUGINS"
echo "============================"

echo "--- /usr/share/hplip/scan/plugins ---"

find /usr/share/hplip/scan/plugins \
  -maxdepth 2 \
  -type f \
  -ls 2>&1 || true

echo "============================"
echo "SOAPHT / HPMUD FILES"
echo "============================"

find / \
  -type f \
  \( -iname '*soapht*' -o -iname '*hpmud*' \) \
  2>/dev/null

echo "============================"
echo "HPLIP PLUGIN STATUS"
echo "============================"

if command -v hp-plugin >/dev/null 2>&1; then
  hp-plugin -s 2>&1 || true
else
  echo "hp-plugin command NOT FOUND"
fi

echo "============================"
echo "HPLIP CONFIG / STATE"
echo "============================"

echo "--- /etc/hp/hplip.conf ---"
cat /etc/hp/hplip.conf 2>&1 || true

echo "--- /var/lib/hp/hplip.state ---"
cat /var/lib/hp/hplip.state 2>&1 || true

echo "============================"
echo "HPAIO LIBRARY"
echo "============================"

ls -l \
  /usr/lib/aarch64-linux-gnu/sane/libsane-hpaio.so* \
  2>&1

ldd \
  /usr/lib/aarch64-linux-gnu/sane/libsane-hpaio.so.1 \
  2>&1 || true

echo "============================"
echo "TEST OPEN DEVICE"
echo "============================"

DEVICE="hpaio:/usb/HP_LaserJet_M1536dnf_MFP?serial=00CND9D5RD6M"

SANE_DEBUG_DLL=255 \
SANE_DEBUG_HPAIO=255 \
scanimage -d "$DEVICE" -A 2>&1

echo "============================"
echo "TEST SCAN OPEN"
echo "============================"

SANE_DEBUG_DLL=255 \
SANE_DEBUG_HPAIO=255 \
scanimage \
  -d "$DEVICE" \
  --format=pnm \
  --mode Gray \
  --resolution 75 \
  -o /tmp/hp_test.pnm \
  2>&1 || true

echo "============================"
echo "TEST FILE"
echo "============================"

ls -lh /tmp/hp_test.pnm 2>&1 || true
file /tmp/hp_test.pnm 2>&1 || true

echo "============================"
echo "KERNEL USB LOG"
echo "============================"

dmesg | tail -150 | \
grep -Ei 'usb|03f0|012a|reset|error|stall|xhci' \
2>&1 || true

echo "============================"
echo "USB TREE"
echo "============================"

ls -l /sys/bus/usb/devices/ 2>&1

echo "########################################"
echo "### DIAGNOSTIC RUN FINISHED"
echo "########################################"
