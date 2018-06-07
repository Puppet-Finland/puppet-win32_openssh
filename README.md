# puppet-win32_openssh

Puppet module for managing win32-openssh, Microsoft's official version of sshd
for Windows.

The Chocolatey package ("openssh") pokes a hole in the Windows firewall by
default, so this module does not need to it separately.

# Usage

To use default settings just

    include ::win32_openssh

This sets up OpenSSH server with default settings. You can customize several
basic settings:

    class { '::win32_openssh':
      listenaddress                => ['0.0.0.0','::1'],
      port                         => 10022,
      permitrootlogin              => 'no',
      passwordauthentication       => 'no',
      disable_microsoft_ssh_server => true,
    }

The default shell for SSH logins depends on what is available. If Powershell
Core is found it is preferred over stock Powershell. This behavior can be
overridden with the $default_shell parameter, which should be in the format
that the
[Set-SSHDefaultShell.ps1](https://github.com/DarwinJS/ChocoPackages/blob/master/openssh/tools/Set-SSHDefaultShell.ps1)
cmdlet expects.

# Limitations

Currently this module can't update the default shell once it has been set unless
registry value HKLM:\SOFTWARE\OpenSSH\DefaultShell is removed manually.
