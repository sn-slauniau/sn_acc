#!/bin/sh

set -x

### allow-list if uploaded separately with virt-customize or alternative options
tmp_allow_list="/tmp/check-allow-list.json"

### retrieve config variables from /tmp/settings.conf and remove the file right after
settings="/tmp/settings.conf"

if [ -r "$settings" ]
then
    . "$settings"
    rm -f "$settings"
fi

### define variables

cache_dst="${CACHE_DIR:-/opt/cache}"
run_dst="${VAR_RUN_DIR:-/var/run}"
rpm="${RPM_NAME:-agent-client-collector-6.0.4-x86_64.rpm}"
echo $rpm
rpm_flags="--noscripts --relocate /var/cache=${cache_dst} --relocate /var/run=${run_dst}"

snusr="${SN_USR:-svc_snacc}"
sngrp="${SN_GRP:-svc_snacc}"
homedir="${ACC_HOME_DIR:-/usr/share/servicenow/agent-client-collector}"
descr="${ACC_DESC:-ServiceNow Agent Client Collector}"
api_key="${MID_API_KEY:-1234ToBeFilled}"
wss="${MID_WSS_URL:-wss://midwebsocket.example.com:443/ws/events}"
sn_url="${SN_URL:-https://install.service-now.com/glide/distribution/builds/package/app-signed}"
acc_start_service="${ACC_START_SERVICE:-0}"

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
	    exit 1
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
        url="${sn_url}/${rpm}"
        curl -O --silent "$url"
        rpm --quiet -i "$rpm" $rpm_flags
	if [ "$?" -ne "0" ]
	then
	    echo "Fatal: cannot install $rpm"
	    exit 1
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
Environment=AGENT_RUN_ROOT=${run_dst}
Environment=RUBYOPT=-Eutf-8
User=$snusr
Group=$sngrp
ExecStart=/usr/share/servicenow/agent-client-collector/bin/acc-service start acc
KillMode=process
Restart=on-failure
RestartSec=1min
CPUWeight=128
CPUQuota=10%
MemoryMax=192M
BlockIOWeight=10
LimitNICE=+15

[Install]
WantedBy=network-online.target
EOF

### backup the original acc.yml and create a new one

cp -a ${acc_config} ${acc_config}.orig
cat << EOF > ${acc_config}
---
# Agent Client Collector configuration
log-level: "info"
backend-url:
 -  "$wss"
api-key: "${api_key}"
connect-without-mid: false
insecure-skip-tls-verify: true
allow-list: ${allow_list}
#allow-list-global-only: false
#check-commands-prefer-installed: false
#disable-assets: false
verify-plugin-signature: true
max-running-checks: 20
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

### backup OOTB existing allow-list
cp -a ${allow_list} "${allow_list}.template"

### if /tmp/check-allow-list.json exists, copy it over to /etc; if not, create a simple file
if [ -r ${tmp_allow_list} ]
then
    cp -a ${tmp_allow_list} ${allow_list}
else
    cat << EOF > ${allow_list}
[
  {
    "args":[
      "--compact|-c",
      "--select=((basic_inventory|data_collection|tcp_connections|running_processes|cloud),?)+",
      "-s",
      "((basic_inventory|data_collection|tcp_connections|running_processes|cloud),?)+",
      "--log-level=(FATAL|ERROR|WARN|INFO|DEBUG)",
      "-l",
      "(FATAL|ERROR|WARN|INFO|DEBUG)",
      "--pretty(=\\d+)?|-p"
    ],
    "exec":"endpoint_discovery.rb",
    "skip_arguments":false,
    "use_regex":true
  },
  {
    "args":[
      "-d",
      "--parent_cache_dir",
      "/Library/Caches/servicenow/agent-client-collector/",
      "C:\\ProgramData\\ServiceNow\\agent-client-collector\\cache",
      "/var/cache/servicenow/agent-client-collector/"
    ],
    "exec":"running_processes.rb",
    "skip_arguments":false
  },
  {
    "args":[
      "-d",
      "--parent_cache_dir",
      "/Library/Caches/servicenow/agent-client-collector/",
      "C:\\ProgramData\\ServiceNow\\agent-client-collector\\cache",
      "/var/cache/servicenow/agent-client-collector/"
    ],
    "exec":"tcp_connections.rb",
    "skip_arguments":false
  },
  {
    "args":[
      "-d",
      "--parent_cache_dir",
      "/Library/Caches/servicenow/agent-client-collector/",
      "C:\\ProgramData\\ServiceNow\\agent-client-collector\\cache",
      "/var/cache/servicenow/agent-client-collector/"
    ],
    "exec":"basic_inventory.rb",
    "skip_arguments":false
  },
  {
    "args":[
      "-d",
      "--parent_cache_dir",
      "/Library/Caches/servicenow/agent-client-collector/",
      "C:\\ProgramData\\ServiceNow\\agent-client-collector\\cache",
      "/var/cache/servicenow/agent-client-collector/"
    ],
    "exec":"data_collection.rb",
    "skip_arguments":false
  },
  {
    "args":[
      ""
    ],
    "exec":"read-file.rb",
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
    "exec":"runUpgrade.rb",
    "skip_arguments":false
  },
  {
    "args": [
      "self-test",
      "--format=(text|json)",
      "--cache-dir=(.*)",
      "--config-file=(.*)",
      "--suite=(.*)",
      "--test=(.*)",
      "--verbose",
      "--test-timeout=(.*)",
      "--exec-timeout=(.*)",
      "--run-timeout=(.*)",
      "list",
      "--tests",
      "--suites",
      "debug",
      "verbose"
    ],
    "exec": "acc",
    "skip_arguments": false,
    "use_regex": true
  },
  {  
    "args":[    
      ""
    ],
    "exec":"osqueryi",
    "skip_arguments":true
  }
]
EOF
fi
    
### apply proper file ownership
id "$snusr" 2>/dev/null
if [ "$?" -ne 0 ]  
then
    useradd -r "$snusr" -s /bin/false -d $homedir -c "$descr"
fi

### (re-)create file structure as needed
# note: /var/run may be reset between the image preparation and the cloned VM first boot
# mkdir -p {/usr/share,/etc,/var/log,/var/run,"$cache_dst"}/servicenow
mkdir -p ${run_dst}/servicenow

### (re-)apply file ownership
chown -R "$snusr:$sngrp" {/usr/share,/etc,/var/log,"${run_dst}","${cache_dst}"}/servicenow

### configure sudo for the user
<< EOF cat > /etc/sudoers.d/01_servicenow
User_Alias     ACC_USERS = ${snusr}
Cmnd_Alias     ACC_CMD = /sbin/dmidecode, /sbin/ss
ACC_USERS      ALL = (root) NOPASSWD:ACC_CMD
EOF

### enable the service
systemctl daemon-reload
systemctl enable acc

### start the service (for regular systems only; keep it off when installing ACC on a custom image
if (( acc_start_service ))
then
    systemctl start acc
    ret=$?
    exit $ret
fi

exit 0
