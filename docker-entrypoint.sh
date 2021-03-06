#!/usr/bin/dumb-init /bin/sh

set -e

echo "Stage ...0"

CONSUL_BIND=
if [ -n "$CONSUL_BIND_INTERFACE" ]; then
  CONSUL_BIND_ADDRESS=$(ip -o -4 addr list $CONSUL_BIND_INTERFACE | head -n1 | awk '{print $4}' | cut -d/ -f1)
  if [ -z "$CONSUL_BIND_ADDRESS" ]; then
    echo "Could not find IP for interface '$CONSUL_BIND_INTERFACE', exiting"
    exit 1
  fi

  CONSUL_BIND="-bind=$CONSUL_BIND_ADDRESS"
  echo "==> Found address '$CONSUL_BIND_ADDRESS' for interface '$CONSUL_BIND_INTERFACE', setting bind option..."
fi

CONSUL_CLIENT=
if [ -n "$CONSUL_CLIENT_INTERFACE" ]; then
  CONSUL_CLIENT_ADDRESS=$(ip -o -4 addr list $CONSUL_CLIENT_INTERFACE | head -n1 | awk '{print $4}' | cut -d/ -f1)
  if [ -z "$CONSUL_CLIENT_ADDRESS" ]; then
    echo "Could not find IP for interface '$CONSUL_CLIENT_INTERFACE', exiting"
    exit 1
  fi

  CONSUL_CLIENT="-client=$CONSUL_CLIENT_ADDRESS"
  echo "==> Found address '$CONSUL_CLIENT_ADDRESS' for interface '$CONSUL_CLIENT_INTERFACE', setting client option..."
fi

CONSUL_DATA=/consul/data
CONSUL_CONFIG=/consul/config

if [ -n "$CONSUL_LOCAL_CONFIG" ]; then
	echo "$CONSUL_LOCAL_CONFIG" > "$CONSUL_CONFIG_DIR/local.json"
fi

echo "Stage ...1"

if [ "${1:0:1}" = '-' ]; then
    set -- consul "$@"
fi

echo "Stage ...2"

if [ "$1" = 'agent' ]; then
    shift
    echo "Stage ...3"
    set -- consul agent \
        -data-dir="$CONSUL_DATA" \
        -config-dir="$CONSUL_CONFIG" \
        $CONSUL_BIND \
        $CONSUL_CLIENT \
        "$@"
elif [ "$1" = 'version' ]; then
    set -- consul "$@"
elif consul --help "$1" 2>&1 | grep -q "consul $1"; then
    set -- consul "$@"
fi

if [ "$1" = 'consul' ]; then
    
    if [ "$(stat -c %u /consul/data)" != "$(id -u consul)" ]; then
        chown consul:consul /consul/data
    fi
    if [ "$(stat -c %u /consul/config)" != "$(id -u consul)" ]; then
        chown consul:consul /consul/config
    fi

    if [ ! -z ${CONSUL_ALLOW_PRIVILEGED_PORTS+x} ]; then
        setcap "cap_net_bind_service=+ep" /bin/consul
    fi

    set -- su-exec consul:consul "$@"
fi

exec "$@"