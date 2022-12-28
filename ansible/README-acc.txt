### Group variables in inventory/all
[linux:vars]
become=yes
become_user=root
become_method=sudo
ansible_user=ec2-user
ansible_user=centos
ansible_ssh_private_key_file=/home/XXX/.ssh/ansible.key
acc_configfile=/etc/servicenow/agent-client-collector/acc.yml
acc_service_owner=sn_acc # default is servicenow
acc_service_group=sn_acc # default is servicenow
mid_webserver_url="wss://XXX:443/ws/events"

[windows:vars]
ansible_connection=winrm
ansible_winrm_transport=certificate
ansible_winrm_transport=basic
ansible_user=ansible
ansible_password="XXX_use_a_vault"
ansible_winrm_cert_pem=ansible_cert_key.pem
ansible_winrm_cert_key_pem=ansible_cert.pem
ansible_winrm_server_cert_validation=ignore

[all:vars]
install_from=url
acc_config_enable_allow_list=true
acc_config_skip_tls_verify=true
acc_config_verify_plugin_signature=true
acc_config_log_level=debug
use_api_key=true
use_basic_auth=false

### System-specific variables
az-centos ansible_user=azureuser ansible_ssh_private_key_file=/home/XXX/.ssh/ansible.key

### Vault Management
ansible-vault edit --vault-password-file /home/XXX/.vault_pass.txt vars/websocket.yml

websocket_api_key: "XXX"
websocket_api_key_enc: "encrypted:XXX"
acc_agent_key_id: XXX

### ACC playbook
ansible-playbook acc_windows.yml --verbose --vault-password-file /home/XXX/.vault_pass.txt --limit windows 
ansible-playbook acc_linux.yml   --verbose --vault-password-file /home/XXX/.vault_pass.txt --limit rhel


files/
├── agent-client-collector-2.10.0-el7-x86_64.rpm
└── agent-client-collector-3.0.0-debian-9_amd64.deb
vars/
└── websocket.yml

