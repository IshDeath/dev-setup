# Sysmon config

`sysmonconfig.xml` is the [SwiftOnSecurity sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config), unmodified
(source version 74, commit `1836897f`). It's licensed CC BY 4.0, and the attribution is in the file's header.

`scripts/install-sysmon.ps1` installs Sysmon with this config, or updates the config on an existing install. Events go to
**Event Viewer → Applications and Services Logs → Microsoft → Windows → Sysmon → Operational**.

To customize it, edit the XML (add `<exclude>` rules for noisy apps on that machine) and re-run the script. It applies the
change with `Sysmon64.exe -c`, so no reinstall is needed. To update to a newer upstream version, replace the file and commit.
