### Intallation steps on the Master Image or via CustomScript extension
$key = "to be filled"
$mid = "mid.example.com"
$wss = "wss://${mid}:443/ws/events"
$msi = "agent-client-collector-3.0.0-windows-x64.msi"
$dst = "$PSScriptRoot\$msi"
$url = "https://install.service-now.com/glide/distribution/builds/package/app-signed/$msi"
Invoke-WebRequest -Uri $url -OutFile $dst

$dstuser = "SYSTEM"

Start-Process msiexec.exe -Wait "/i ${dst} /quiet /qn /norestart ACC_API_KEY=${key} ACC_MID=${wss} LOCALUSERNAME=${dstuser} START_SERVICE=False"

### Agent upgrade
# msiexec /i "$dst" /quiet /qn /norestart

### On the Master Image only, to avoid the agent to start automatically when the image is edited online
# Set-Service -Name "AgentClientCollector" -StartupType Manual

### Manual Testing on the Golden Image
# Start-Service -Name AgentClientCollector

### Steps to clean up the agent config
# Stop-Service -Name AgentClientCollector
# Remove-Item -Path C:\ProgramData\ServiceNow\agent-client-collector\cache\agent_now_id

### When cloned from a Master Image, to be executed just once as firstboot on the target VDI instance
# Set-Service -Name "AgentClientCollector" -StartupType AutomaticDelayedStart
 
