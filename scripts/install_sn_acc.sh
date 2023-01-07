#!/bin/sh

set -x

### define variables

cache_dst="/opt/cache"
if [ -n "$1" ]
then
	rpm="$1"
else
	rpm="agent-client-collector-2.9.0-el7-x86_64.rpm"
fi
echo $rpm
rpm_flags="--noscripts --relocate /var/cache=${cache_dst}"

snusr="svc_accv"
sngrp="svc_accv"
homedir="/usr/share/servicenow/agent-client-collector"
descr="ServiceNow Agent Client Collector"
api_key="1234ToBeFilled"
wss="wss://midwebsocket.example.com:443/ws/events"

acc_systemd="/usr/lib/systemd/system/acc.service"
acc_config="/etc/servicenow/agent-client-collector/acc.yml"
allow_list="/etc/servicenow/agent-client-collector/check-allow-list.json"

new=1

### query for existing agent installed
rpm --quiet -q agent-client-collector

if [ "$?" -eq "0" ]
then
### upgrade the existing agent

	new=0
	systemctl stop acc
	rpm --quiet -U "$rpm" $rpm_flags
        if [ "$?" -ne "0" ]
        then
                echo "Fatal: cannot upgrade $rpm"
        fi

### steps using a full uninstall - not needed in normal cases
#	rm -f "${acc_systemd}"
#	rm -f "${acc_config}"
#	rm -f "${allow_list}"
#	systemctl daemon-reload
#	rpm --quiet -e agent-client-collector --noscripts
#	userdel -f ${snusr}	

else
### install a fresh new install of the agent

	rpm --quiet -i "$rpm" $rpm_flags
	if [ "$?" -ne "0" ]
	then
		echo "Fatal: cannot install $rpm"
	fi
fi

### replace the agent systemd config
cat << EOF > ${acc_systemd}
[Unit]
Description=Agent-Now acc
After=network-online.target

[Service]
Environment=AGENT_ROOT=/usr/share
Environment=AGENT_CACHE_ROOT=${cache_dst}
Environment=AGENT_CONFIG_ROOT=/etc
Environment=AGENT_LOG_ROOT=/var/log
Environment=AGENT_RUN_ROOT=/var/run
Environment=RUBYOPT=-Eutf-8
User=$snusr
Group=$sngrp
ExecStart=/usr/share/servicenow/agent-client-collector/bin/acc-service start acc
KillMode=process
Restart=on-failure
RestartSec=1min
CPUShares=128
CPUQuota=10%
MemoryLimit=192M
BlockIOWeight=10
LimitNICE=+15

[Install]
WantedBy=network-online.target
EOF

### create acc.yml config file

cat << EOF > ${acc_config}
---
# Agent Client Collector configuration
backend-url:
 -  "$wss"
api-key: "${api_key}"
log-level: "info"
insecure-skip-tls-verify: true
allow-list: ${allow_list}
verify-plugin-signature: true
max-running-checks: 10
disable-sockets: true
disable-api: true
statsd-disable: true
enable-auto-mid-selection: false
agent_cpu_threshold:
 cpu_percentage_limit: 25
 repeated_high_cpu_num: 3
 monitor_interval_sec: 60
 agent_cpu_threshold_disabled: false
EOF

### create check-allow-list.json file

cat << EOF > ${allow_list}
[
  {  
    "args":[    
      ""
    ],
    "exec":"endpoint_discovery.rb",
    "skip_arguments":true
  },
  {  
    "args":[    
      ""
    ],
    "exec":"live_ci_view.rb",
    "skip_arguments":false
  },
  {  
    "args":[    
      ""
    ],
    "exec":"osqueryi",
    "skip_arguments":true
  },
  {  
    "args":[    
      "agent"
    ],
    "exec":"Restart",
    "skip_arguments":false
  },
  {  
    "args":[    
      ""
    ],
    "exec":"sam_processor.rb",
    "skip_arguments":false
  }
]
EOF

### apply proper file ownership
id "$snusr" 2>/dev/null
if [ "$?" -ne 0 ]  
then
	useradd -r "$snusr" -s /bin/false -d $homedir -c "$descr"
fi

### (re-)apply file ownership
chown -R "$snusr:$sngrp" {/usr/share,/etc,/var/log,"$cache_dst"}/servicenow

### configure sudo for the user
<< EOF cat > /etc/sudoers.d/01_servicenow
User_Alias     ACC_USERS = ${snusr}
Cmnd_Alias     ACC_CMD = /sbin/dmidecode, /sbin/ss
ACC_USERS      ALL = (root) NOPASSWD:ACC_CMD
EOF

### start the service
systemctl daemon-reload
systemctl start acc
ret=$?
exit $ret
