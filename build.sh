#!/bin/bash
# build.sh
# Created on: Fri 24 Apr 2026 09:02:03 PM CEST
#
#  ____   __  ____  __
# (  _ \ /. |(  _ \/  )
#  )___/(_  _))___/ )(
# (__)    (_)(__)  (__)
#
# Description:
#
CERTIFICATE_FOLDER=$PWD/conf/certs/
OPENVPN_FOLDER=$PWD/conf/ovpn/
OUT_FOLDER=$PWD/out/
DEPENDENCY=(fzf docker openssl dialog tmux)
DEPLOY=

function usage () {
	echo -e "\e[1;31mDeploy b0mb!\e[m" 1>&2
}

function setup_certificates() {
	[ ! -d "$CERTIFICATE_FOLDER" ] && mkdir -p $CERTIFICATE_FOLDER

	if [ "$DEPLOY" = "testing" ]; then
		[ -f "$CERTIFICATE_FOLDER/b0mb.key" ] && [ -f "$CERTIFICATE_FOLDER/b0mb.crt" ] && return
		openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
			-keyout $CERTIFICATE_FOLDER/b0mb.key \
			-out $CERTIFICATE_FOLDER/b0mb.crt \
			-subj "/CN=b0mb.local" \
			-addext "subjectAltName=DNS:b0mb.local,DNS:www.b0mb.local,DNS:api.b0mb.local,DNS:stunnel.b0mb.local,DNS:ovpn.b0mb.local"

		sudo trust anchor --store $CERTIFICATE_FOLDER/b0mb.crt
		sudo update-ca-trust
		cp -r "$CERTIFICATE_FOLDER/b0mb.key" "$OUT_FOLDER"
		cp -r "$CERTIFICATE_FOLDER/b0mb.crt" "$OUT_FOLDER"
	else
		#--deploy-hook "cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $CERTIFICATE_FOLDER/b0mb.crt && \
		#       cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $CERTIFICATE_FOLDER/b0mb.key && \
		#       docker compose -f $PWD/docker-compose.yml restart"
		echo "in prod certbot here"
	fi
}

function setup_openvpn() {
	echo -e "Enabling the vpn kernel modules -> \e[36m:)\e[0m"
	if [ "$DEPLOY" = "prod" ]; then
		echo "tun" | sudo tee /etc/modules-load.d/tun.conf
		echo "iptable_nat" | sudo tee /etc/modules-load.d/iptable_nat.conf
	fi
	sudo modprobe tun
	sudo modprobe iptable_nat
	[ -d "$OPENVPN_FOLDER" ] && return || mkdir -p $OPENVPN_FOLDER
	sudo docker run -v $PWD/conf/ovpn:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u tcp://stunnel.yourdomain.com
	sudo docker run -v $PWD/conf/ovpn:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki nopass
	sudo docker run -v $PWD/conf/ovpn:/etc/openvpn --rm -it kylemanna/openvpn easyrsa build-client-full p4p1 nopass
	echo -e "Generating operator .ovpn file in ./p4p1.ovpn -> \e[36m:)\e[0m"
	sudo docker run -v $PWD/conf/ovpn:/etc/openvpn --rm kylemanna/openvpn ovpn_getclient p4p1 > "$OUT_FOLDER/p4p1.ovpn"
}

function generate_stunnel_conf() {
	echo -e "Creating your operator stunnel setup -> \e[36m:)\e[0m"
	cat << EOF > $OUT_FOLDER/stunnel.conf
client = yes
CAfile = /etc/stunnel/b0mb.crt
verify = 2
[openvpn]
accept = 127.0.0.1:1194
connect = stunnel.b0mb.local:443
retry = yes
EOF

}

while getopts "c" o; do
	case "${o}" in
		c)
			echo "caca"
			;;
		*)
			usage
			;;
	esac
done
shift $((OPTIND-1))

[ ! -d "$OUT_FOLDER" ] && mkdir -p $OUT_FOLDER

while DEPLOY=$(echo -e "prod\ntesting" | fzf --prompt="Deployment: " --height=80% --layout=reverse --border=rounded --margin=20%,30% --padding=1 --header="Deployment mode"); do
	if [ ! -z "$DEPLOY" ]; then
		break
	else
		echo -e "Deployment mode is mandatory -> \e[1;31m:(\e[0m"
	fi
done

echo -e "Deploying to: $DEPLOY -> \e[36m:)\e[0m"

echo -e "Starting docker -> \e[36m:)\e[0m"
sudo systemctl start docker

echo -e "Deploying certificate for b0mb -> \e[36m:)\e[0m"
setup_certificates

echo -e "Creating the vpn config -> \e[36m:)\e[0m"
setup_openvpn

echo -e "Starting the compose -> \e[36m:)\e[0m"
if [ "$DEPLOY" = "testing" ]; then
	sudo docker compose -f $PWD/docker-compose.yml up --build
fi
