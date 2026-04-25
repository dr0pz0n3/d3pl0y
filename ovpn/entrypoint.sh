#!/bin/sh
# entrypoint.sh
# Created on: Sat 25 Apr 2026 06:12:14 PM CEST
#
#  ____   __  ____  __
# (  _ \ /. |(  _ \/  )
#  )___/(_  _))___/ )(
# (__)    (_)(__)  (__)
#
# Description:

EASYRSA=/usr/share/easy-rsa
OVPN_DIR=/etc/openvpn

# init PKI if not already done
if [ ! -d "$OVPN_DIR/pki" ]; then
    cd $EASYRSA
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    ./easyrsa --batch build-server-full server nopass
    ./easyrsa --batch gen-dh
    openvpn --genkey secret $OVPN_DIR/ta.key
    cp pki/ca.crt $OVPN_DIR/
    cp pki/issued/server.crt $OVPN_DIR/
    cp pki/private/server.key $OVPN_DIR/
    cp pki/dh.pem $OVPN_DIR/
fi

mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

exec openvpn --config $OVPN_DIR/openvpn.conf

