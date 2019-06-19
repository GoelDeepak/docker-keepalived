# docker-keepalived
---
## Purpose

A Dockerized Keepalived designed for simple high availability (HA) in multi-host container deployments. [Keepalived](http://www.keepalived.org/) provides failover for one or more Virtual IP addresses (VIPs) so they are always available, even if a host fails.

## Health Checks

If you'd like the health check to only check for something listening on a specified port, rather than an address and port, only set the CHECK_PORT variable, not the CHECK_IP variable.

If you do want to check the address and port combination, set the CHECK_IP variable to the same value as the VIRTUAL_IP variable.

If you want to use your own custom script, set the CHECK_SCRIPT variable.

## Status Checking

You can check the status of Keepalived by opening an interactive shell in the container and typing `status`. This is an alias for `pidof keepalived | kill -s USR1; cat /tmp/keepalived.data`. As you can surmise, sending the USR1 signal to the keepalived process causes it to write a status file to **/tmp/keepalived**.

You can also confirm Keepalived is running on any particular host by confirming a process is listening on protocol number 112 with command `ss -lwn`. You can confirm that process is keepalived with `sudo ss -lwnp`.

## Using the Docker Run Command

If you'd like to quickly test the built image at the CLI using the `docker run` command, something like this will work:

```
docker run -d --privileged --net host --name keepalived -e VIRTUAL_IP=10.11.12.99 -e CHECK_PORT=443 -e VIRTUAL_MASK=24 -e VRID=99 -e INTERFACE=eht0 docker-keepalived
```
