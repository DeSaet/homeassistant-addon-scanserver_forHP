ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        jq \
        dbus \
        udev \
        libusb-1.0-0 \
        hplip \
        hplip-data \
        printer-driver-hpcups \
        sane-utils \
        libsane1 \
        avahi-daemon \
        python3 \
        python3-dbus \
        python3-lxml \
        python3-pil \
        python3-reportlab \
        python3-pexpect \
        usbutils \
        nano && \
    rm -rf /var/lib/apt/lists/*

RUN echo "========== INSTALLED HPAIO ==========" && \
    find /usr -name "*hpaio*" 2>/dev/null || true && \
    echo "========== SANE LIBS ==========" && \
    find /usr -name "libsane-*.so*" 2>/dev/null || true

COPY rootfs /

COPY run.sh /run.sh
COPY setup.sh /setup.sh

RUN chmod +x /run.sh /setup.sh /usr/bin/get_scan_filename

CMD ["/run.sh"]
