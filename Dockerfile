FROM ghcr.io/connum/debian-base-scansupport:7.7.1

LABEL io.hass.version="1.0" io.hass.type="addon" io.hass.arch="aarch64|amd64"

# Add env
ENV TERM="xterm-256color"

# Setup base
RUN set -ex \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
    nano \
    usbutils \
    hplip \
    printer-driver-hpcups \
 && which hp-info \
 && hp-info --version \
 && find /usr -name "*hpaio*"

# Copy root filesystem
COPY rootfs /

RUN chmod a+x /run.sh /setup.sh \
    && . /setup.sh \
    && rm /setup.sh

CMD ["/run.sh"]
