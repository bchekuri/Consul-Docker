FROM alpine:3.8
MAINTAINER Bharath Chekuri <bharathchekuriapps@gmail.com>

# Consul release version
ENV CONSUL_VERSION=1.4.0

# Consul downloan url
ENV CONSUL_DOWNLOAN_URL=https://releases.hashicorp.com


# Create consul user and group
RUN addgroup consul && \
    adduser -S -G consul consul


# Install Consul
RUN set -eux && \
    apk add --no-cache ca-certificates curl dumb-init gnupg libcap openssl su-exec iputils && \
    mkdir -p /tmp/build && \
    cd /tmp/build && \
    apkArch="$(apk --print-arch)" && \
    case "${apkArch}" in \
        aarch64) consulArch='arm64' ;; \
        armhf) consulArch='arm' ;; \
        x86) consulArch='386' ;; \
        x86_64) consulArch='amd64' ;; \
        *) echo >&2 "error: unsupported architecture: ${apkArch} (see ${CONSUL_DOWNLOAN_URL}/consul/${CONSUL_VERSION}/)" && exit 1 ;; \
    esac && \
    wget ${CONSUL_DOWNLOAN_URL}/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${consulArch}.zip && \
    unzip -d /bin consul_${CONSUL_VERSION}_linux_${consulArch}.zip && \
    cd /tmp && \
    rm -rf /tmp/build && \
    apk del gnupg openssl && \
    rm -rf /root/.gnupg && \
    consul version

# Create Consul data and config directory
RUN mkdir -p /consul/data && \
    mkdir -p /consul/config && \
    chown -R consul:consul /consul


RUN test -e /etc/nsswitch.conf || echo 'hosts: files dns' > /etc/nsswitch.conf

VOLUME /consul/data

# Request forwarding.
EXPOSE 8300

# Consul agents. LAN is within the datacenter and WAN is between just the Consul
# servers in all datacenters.
EXPOSE 8301 8301/udp 8302 8302/udp


# HTTP and DNS (both TCP and UDP) are the primary interfaces that applications
# use to interact with Consul.
EXPOSE 8500 8600 8600/udp

# Entry point script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN /usr/bin/dos2unix /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

# By default you'll get an insecure single-node development server that stores
# everything in RAM, exposes a web UI and HTTP endpoints, and bootstraps itself.
#CMD tail -f /dev/null
CMD ["agent", "-dev", "-client", "0.0.0.0"]