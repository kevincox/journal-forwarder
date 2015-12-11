# journal-forwarder
A simple script to forward journald logs over HTTP somewhat reliabily.

## Configuration

All the configuration is passed in as environment variables the only required value is `JF_URL` which is the url to send the logs to. If you prefer you can set `JF_URL_SRC` instead to read the URL out of a file.

All the other configuraion options are at the top of the source file.

## Requirements

On nixos the following packages are required:

- coreutils
- curl
- gnused
- jq
- systemd
- utillinux (butilt with systemd support)

## Questions

Open an issue so that I can answer and add docs.
