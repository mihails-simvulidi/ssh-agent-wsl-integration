# PURPOSE

Makes Windows SSH agent (e. g. Bitwarden) available in Windows Subsystem for Linux (Debian-based).

# INSTALL

In Windows Subsystem for Linux, run the install.sh script, then reopen the shell to reload environment.

```bash
./install.sh
```

Verify that relay works:

```bash
ssh-add -L
```
