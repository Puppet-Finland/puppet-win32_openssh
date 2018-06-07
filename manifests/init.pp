#
# == Class: win32_openssh
#
# Install and configure win32-openssh
#
class win32_openssh
(
    Enum['present','absent'] $ensure = 'present'
)
{
    $install_options = ['--params="/SSHServerFeature"']

    package { 'openssh':
        ensure            => $ensure,
        provider          => 'chocolatey',
        install_options   => $install_options,
        uninstall_options => $install_options,
    }

    if $ensure == 'present' {
        service { 'sshd':
            ensure  => 'running',
            enable  => true,
            require => Package['openssh'],
        }
    }
}
