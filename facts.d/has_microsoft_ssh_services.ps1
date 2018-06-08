$services = @("ssh-agent","sshproxy","sshbroker")

foreach ($service in $services) {
    if (Get-Service $service 2> $null) {
        Write-Host "has_${service}_service=true"
    } else {
        Write-Host "has_${service}_service=false"
    }
}
