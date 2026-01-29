$msi = "AGENT_MSI"
$url = "https://install.service-now.com/glide/distribution/builds/package/app-signed/$msi"
$dest = "$env:TEMP\$msi"
Invoke-WebRequest -Uri $url -OutFile $dest

$inst_url = "https://MY_INSTANCE.service-now.com/"
$key = "MY_ICS_KEY"
Start-Process msiexec.exe -ArgumentList "/i", $dest, "/quiet /qn /norestart CONNECT_WITHOUT_MID=true REGISTRATION_KEY=$key INSTANCE_URL=$inst_url LOCALUSERNAME=SYSTEM START_SERVICE=False" -Wait


