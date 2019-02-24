#!/bin/bash
set -e

opts=(
	dc_local_interfaces '0.0.0.0 ; ::0'
	dc_other_hostnames ''
	dc_relay_nets '0.0.0.0/0'
)

if [ ! -z "$SMTP_MULTI_RELAY" ]; then
	# Sends incoming SMTP to multiple SMTP hosts.
	# Usage:
	# SMTP_MULTI_RELAY=host1::25%host2::25
	# SMTP_MULTI_RELAY_PASSWD="host1:user1:password1"$'\n'"host2:user2:password2"
	#
	_last_relay=""
	_counter=0
	# We need to create separate routers for each host.
	# Last host will fall into the default `smarthost` router,
	# which is parametrized with Debian's `dc_smarthost`.
	echo > /etc/exim4/conf.d/router/180_exim4-multi_relay_custom
	IFS='%' read -ra RELAYS <<< "$SMTP_MULTI_RELAY"
	for relay in "${RELAYS[@]}"; do
		if [ ! -z "$_last_relay" ]; then
			cat >> /etc/exim4/conf.d/router/180_exim4-multi_relay_custom <<EOF

smarthost$_counter:
  debug_print = "R: smarthost$_counter for \$local_part@\$domain"
  driver = manualroute
  domains = ! +local_domains
  transport = remote_smtp_smarthost
  route_list = * $_last_relay byname
  host_find_failed = ignore
  same_domain_copy_routing = yes
  # unseen is the key here: see https://serverfault.com/a/318264
  unseen

EOF
		fi
		_last_relay="$relay"
		((_counter++))
	done

	opts+=(
		dc_eximconfig_configtype 'satellite'
		dc_smarthost "$_last_relay"
		dc_use_split_config 'true'
	)
	echo "$SMTP_MULTI_RELAY_PASSWD" > /etc/exim4/passwd.client
elif [ "$GMAIL_USER" -a "$GMAIL_PASSWORD" ]; then
	# see https://wiki.debian.org/GmailAndExim4
	opts+=(
		dc_eximconfig_configtype 'smarthost'
		dc_smarthost 'smtp.gmail.com::587'
	)
	echo "*.google.com:$GMAIL_USER:$GMAIL_PASSWORD" > /etc/exim4/passwd.client
elif [ ! -z "$SMTP_RELAY" ]; then
	opts+=(
		dc_eximconfig_configtype 'smarthost'
		dc_smarthost "$SMTP_RELAY"
	)
	if [ ! -z "$SMTP_RELAY_USER" ]; then
		echo "$SMTP_RELAY_TARGET:$SMTP_RELAY_USER:$SMTP_RELAY_PASSWORD" > /etc/exim4/passwd.client
	fi
else
	opts+=(
		dc_eximconfig_configtype 'internet'
	)
fi

set-exim4-update-conf "${opts[@]}"

if [ "$(id -u)" = '0' ]; then
	mkdir -p /var/spool/exim4 /var/log/exim4 || :
	chown -R Debian-exim:Debian-exim /var/spool/exim4 /var/log/exim4 || :
fi

exec "$@"
