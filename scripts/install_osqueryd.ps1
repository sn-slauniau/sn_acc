# Install latest osquery

$msi = "osquery-5.6.0.msi"
$url = "https://pkg.osquery.io/windows/$msi"
$dst = "$PSScriptRoot\$msi"
Invoke-WebRequest -Uri $url -OutFile $dst
# msiexec /i "$dst" /quiet /qn /norestart
Start-Process msiexec.exe -Wait "/i $dst /quiet /qn /norestart"

# Configure osqueryd service

$flags = "--logger_rotate=true
--logger_rotate_size=26214400
--logger_rotate_max_files=1
--watchdog_level=-1
--config_path=C:\Program Files\osquery\osquery-sam.conf"
Set-Content -Path 'C:\Program Files\osquery\osquery.flags.default' -Value "$flags"

$conf = @'
{
  "options": {
    "config_plugin": "filesystem",
    "logger_plugin": "filesystem",
    "utc": "true"
  },
  "schedule": {
    "sam_process_info": {
      "query": "select name ,pid, elapsed_time, start_time, user_time, system_time, username from processes p JOIN users u ON u.uid = p.uid where p.elapsed_time != -1 ;",
      "snapshot" : true,
      "interval": 300
    },
    "system_info": {
      "query": "SELECT hostname, cpu_brand, physical_memory FROM system_info;",
      "interval": 3600
    }
  },
  "decorators": {
    "load": [
      "SELECT uuid AS host_uuid FROM system_info;",
      "SELECT user AS username FROM logged_in_users ORDER BY time DESC LIMIT 1;"
    ]
  },
  "packs": {
  }
}
'@
Set-Content -Path 'C:\Program Files\osquery\osquery-sam.conf' -Value "$conf"

cd 'C:\Program Files\osquery'
.\manage-osqueryd.ps1 -uninstall
.\manage-osqueryd.ps1 -install
Restart-Service osqueryd

