ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        jq \
        dbus \
        hplip \
        printer-driver-hpcups \
        sane-utils \
        libsane1 \
        usbutils \
        nano && \
    rm -rf /var/lib/apt/lists/*

COPY rootfs /

COPY run.sh /run.sh
COPY setup.sh /setup.sh

RUN chmod +x /run.sh /setup.sh /usr/bin/get_scan_filename

CMD ["/run.sh"]
