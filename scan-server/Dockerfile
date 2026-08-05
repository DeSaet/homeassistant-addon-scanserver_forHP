ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV DEBIAN_FRONTEND=noninteractive

apt-get install -y \
    curl \
    jq \
    dbus \
    udev \
    libusb-1.0-0 \
    hplip \
    printer-driver-hpcups \
    sane-utils \
    libsane1 \
    usbutils \
    nano && \
    rm -rf /var/lib/apt/lists/*

RUN echo "========== INSTALLED HPAIO ==========" && \
    find /usr -name "*hpaio*" || true && \
    echo "========== SANE LIBS ==========" && \
    find /usr -name "libsane-*.so*" || true

COPY rootfs /

COPY run.sh /run.sh
COPY setup.sh /setup.sh

RUN chmod +x /run.sh /setup.sh /usr/bin/get_scan_filename

CMD ["/run.sh"]

udevadm info --version || true
