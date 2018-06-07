#
# == Class: win32_openssh
#
# Install and configure win32-openssh (ssh client and server)
#
# == Paramemeters
#
# [*ensure*]
#   Status of win32-openssh on the system. Valid values are 'present' (default) 
#   and 'absent'.
# [*listenaddress*]
#   Local IP-addresses sshd binds to. This can be an string containing one bind
#   address or an array containing one or more. Defaults to "0.0.0.0" (all
#   IPv4 interfaces).
# [*port*]
#   Port on which sshd listens on. Defaults to 22.
# [*permitrootlogin*]
#   Allow root logins (yes/no/without-password). Defaults to "yes".
# [*passwordauthentication*]
#   Allow logins using password (yes/no). Defaults to "yes".
# [*default_shell*]
#   Default shell to use with ssh. See README.md for details.
#
class win32_openssh
(
    Enum['present','absent']            $ensure = 'present',
    Variant[String,Array[String]]       $listenaddress = '0.0.0.0',
    Integer[1,65535]                    $port = 22,
    Enum['yes','no','without-password'] $permitrootlogin = 'yes',
    Enum['yes','no']                    $passwordauthentication = 'yes',
    Optional[String]                    $default_shell = undef
)
{
    $listenaddresses = any2array($listenaddress)
    $install_options = ['--params="/SSHServerFeature"']

    package { 'openssh':
        ensure            => $ensure,
        provider          => 'chocolatey',
        install_options   => $install_options,
        uninstall_options => $install_options,
        require           => Class['::chocolatey'],
    }

    file { 'sshd_config':
        ensure  => $ensure,
        name    => 'C:/ProgramData/ssh/sshd_config',
        content => template('win32_openssh/sshd_config.erb'),
        require => Package['openssh'],
    }

    # Set default shell for ssh
    $pathspec = $default_shell ? {
        undef   => '$env:programfiles\PowerShell\*\pwsh.exe;$env:programfiles\PowerShell\*\Powershell.exe;c:\windows\system32\windowspowershell\v1.0\powershell.exe',
        default => $default_shell,
    }

    exec { 'Set-SSHDefaultShell.ps1':
        command  => "C:/ProgramData/chocolatey/lib/openssh/tools/Set-SSHDefaultShell.ps1 -PathSpecsToProbeForShellEXEString \"${pathspec}\"",
        provider => 'powershell',
        require  => Package['openssh'],
    }

    if $ensure == 'present' {
        service { 'sshd':
            ensure  => 'running',
            enable  => true,
            require => File['sshd_config'],
        }
    }
}
