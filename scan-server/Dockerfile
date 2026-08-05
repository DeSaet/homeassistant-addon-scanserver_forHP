ARG BUILD_FROM
FROM ${BUILD_FROM}

LABEL io.hass.version="1.0"
LABEL io.hass.type="addon"
LABEL io.hass.arch="aarch64|amd64"

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
COPY run.sh /
COPY setup.sh /

RUN chmod +x \
        /run.sh \
        /usr/bin/get_scan_filename

CMD ["/run.sh"]
