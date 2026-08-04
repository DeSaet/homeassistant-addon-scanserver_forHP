FROM ghcr.io/connum/debian-base-scansupport:7.7.1

LABEL \
    io.hass.type="addon" \
    io.hass.arch="aarch64|amd64"

ENV \
    TERM=xterm-256color \
    SANE_CONFIG_DIR=/etc/sane.d

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        hplip \
        hplip-data \
        printer-driver-hpcups \
        sane-utils \
        libsane1 \
        usbutils \
        jq \
        curl \
        dbus \
        nano && \
    rm -rf /var/lib/apt/lists/*

COPY rootfs /

RUN chmod +x \
        /run.sh \
        /usr/bin/get_scan_filename

CMD ["/run.sh"]
