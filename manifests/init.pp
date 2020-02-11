#
# == Class: win32_openssh
#
# Install and configure win32-openssh (ssh client and server)
#
# == Paramemeters
#
# [*manage_packetfilter*]
#   Whether to open port for SSH connections in the Windows Firewall or not. 
#   Defaults to true.
# [*manage_package*]
#   Whether the package installation is managed or not. 
#   Defaults to true.
# [*ensure*]
#   Status of win32-openssh on the system. Valid values are 'present' (default) 
#   and 'absent'.
# [*listenaddress*]
#   Local IP-addresses sshd binds to. This can be an string containing one bind
#   address or an array containing one or more. Defaults to "0.0.0.0" (all
#   IPv4 interfaces).
# [*port*]
#   Port on which sshd listens on. Defaults to 22.
# [*allow_address_ipv4*]
#   IP address(es) or network(s) to allow SSH connections from (string or 
#   array, default: '127.0.0.1'). Modifies Windows Firewall settings.
# [*permitrootlogin*]
#   Allow root logins (yes/no/without-password). Defaults to "yes".
# [*passwordauthentication*]
#   Allow logins using password (yes/no). Defaults to "yes".
# [*default_shell*]
#   Default shell to use with ssh. See README.md for details.
# [*disable_microsoft_ssh_server*]
#   Disable "Microsoft SSH server" which may occupy port 22 on some Windows
#   10 instances. It consists of three services: "ssh-agent", "sshproxy" and 
#   "sshbroker". Valid values are true (default) and false.
#
class win32_openssh
(
    Boolean                             $manage_packetfilter = true,
    Boolean                             $manage_package = true,
    Enum['present','absent']            $ensure = 'present',
    Variant[String,Array[String]]       $listenaddress = '0.0.0.0',
    Integer[1,65535]                    $port = 22,
    Variant[String,Array[String]]       $allow_address_ipv4 = '127.0.0.1',
    Enum['yes','no','without-password'] $permitrootlogin = 'yes',
    Enum['yes','no']                    $passwordauthentication = 'yes',
    Boolean                             $disable_microsoft_ssh_server = true,
    Optional[String]                    $default_shell = undef,
)
{
    $listenaddresses = any2array($listenaddress)
    $install_options = ['--params="/SSHServerFeature',"/SSHServerPort:${port}\""]

    if $disable_microsoft_ssh_server {
        $services = ['ssh-agent','sshproxy','sshbroker']
        $services.each |$service| {
            if str2bool($facts["has_${service}_service"]) {
                service { $service:
                    ensure => 'stopped',
                    enable => false,
                }
            }
        }
    }

    package { 'openssh':
        ensure            => $manage_package,
        provider          => 'chocolatey',
        install_options   => $install_options,
        uninstall_options => $install_options,
        require           => Class['::chocolatey'],
    }

    $require_package = $manage_package ? {
      true  => Package['openssh'],
      false => Service['sshd'],
    }

    file { 'sshd_config':
        ensure  => $ensure,
        name    => 'C:/ProgramData/ssh/sshd_config',
        content => template('win32_openssh/sshd_config.erb'),
        notify  => Service['sshd'],
    }

    # Set default shell for ssh, unless it is set (to something) already
    $pathspec = $default_shell ? {
        undef   => '$env:programfiles\PowerShell\*\pwsh.exe;$env:programfiles\PowerShell\*\Powershell.exe;c:\windows\system32\windowspowershell\v1.0\powershell.exe',
        default => $default_shell,
    }

    exec { 'Set-SSHDefaultShell.ps1':
        command  => "C:/ProgramData/chocolatey/lib/openssh/tools/Set-SSHDefaultShell.ps1 -PathSpecsToProbeForShellEXEString \"${pathspec}\"",
        unless   => 'if ((Get-Item -Path HKLM:\SOFTWARE\openssh -Erroraction ignore).property -contains "DefaultShell") { exit 0 } else { exit 1 }',
        provider => 'powershell',
        require  => $require_package,
    }

    if $ensure == 'present' {
        service { 'sshd':
            ensure => 'running',
            enable => true,
        }
    }

    if $manage_packetfilter {
        $allow_address_ipv4_array = any2array($allow_address_ipv4)
        $remote_ips = join($allow_address_ipv4_array, ',')

        # Set defaults so that we don't have to repeat useless parameters
        # just to ensure the Chocolatey-generated rule is absent.
        $firewall_defaults = {
            'direction'  => 'in',
            'action'     => 'allow',
            'protocol'   => 'TCP',
            'local_port' => $port,
        }

        # Remove the Chocolatey-generated rule
        ::windows_firewall::exception { 'SSHD Port OpenSSH (chocolatey package: openssh)':
            ensure       => 'absent',
            display_name => 'SSHD Port OpenSSH (chocolatey package: openssh)',
            *            => $firewall_defaults,
        }

        ::windows_firewall::exception { 'SSH-in (puppet)':
            ensure       => 'present',
            display_name => 'SSH-in (puppet)',
            description  => "Allow SSH connections from ${remote_ips} to tcp port ${port}",
            enabled      => true,
            remote_ip    => $remote_ips,
            *            => $firewall_defaults,
        }
    }
}
