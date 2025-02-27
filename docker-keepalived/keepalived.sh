#!/bin/bash

# Substitute variables in config file.
/bin/sed -i "s/{{VIRTUAL_IP}}/${VIRTUAL_IP}/g" /etc/keepalived/keepalived.conf
/bin/sed -i "s/{{VIRTUAL_MASK}}/${VIRTUAL_MASK}/g" /etc/keepalived/keepalived.conf
/bin/sed -i "s#{{CHECK_SCRIPT}}#${CHECK_SCRIPT}#g" /etc/keepalived/keepalived.conf
/bin/sed -i "s/{{VRID}}/${VRID}/g" /etc/keepalived/keepalived.conf
/bin/sed -i "s/{{INTERFACE}}/${INTERFACE}/g" /etc/keepalived/keepalived.conf

# Make sure we react to these signals by running stop() when we see them - for clean shutdown
# And then exiting
trap "stop; exit 0;" SIGTERM SIGINT

stop()
{
  # We're here because we've seen SIGTERM, likely via a Docker stop command or similar
  # Let's shutdown cleanly
  echo "SIGTERM caught, terminating keepalived process..."
  # Record PIDs
  pid=$(pidof keepalived)
  # Kill them
  kill -TERM $pid > /dev/null 2>&1
  # Wait until processes have been killed.
  # Use 'wait $pid' instead if you dislike using sleep (the wait command has less OS support)
  sleep 1
  echo "Terminated."
  exit 0
}

# Make sure the variables we need to run are populated and (roughly) valid

if ! [[ $VIRTUAL_IP =~ ^(([1-9]|[1-9][0-9]|1[0-9]{2}|2[0-2][0-3])\.)(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){2}([1-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$ ]]; then
  echo "The VIRTUAL_IP environment variable is null or not a valid IP address, exiting..."
  exit 1
fi

if ! [[ $VIRTUAL_MASK =~ ^([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
  echo "The VIRTUAL_MASK environment variable is null or not a valid subnet mask, exiting..."
  exit 1
fi

if ! [[ $VRID =~ ^([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
  echo "The VRID environment variable is null or not a number between 1 and 255, exiting..."
  exit 1
fi

# Possibly some interfaces are named and don't end in a number so beware of this one
if ! [[ $INTERFACE =~ ^.*[0-9]$ ]]; then
  echo "The INTERFACE environment variable is null or doesn't end in a number, exiting..."
  exit 1
fi

# Make sure to clean up VIP before start (in case of ungraceful shutdown)
if [[ $(ip addr | grep $INTERFACE | grep $VIRTUAL_IP) ]]
  then
    ip addr del $VIRTUAL_IP/$VIRTUAL_MASK dev $INTERFACE
fi

# This loop runs till until we've started up successfully
while true; do

  # Check if Keepalived is running by recording it's PID (if it's not running $pid will be null):
  pid=$(pidof keepalived)

  # If $pid is null, do this to start or restart Keepalived:
  while [ -z "$pid" ]; do
    echo "Displaying resulting /etc/keepalived/keepalived.conf contents..."
    cat /etc/keepalived/keepalived.conf
    echo "Starting Keepalived in the background..."
    /usr/sbin/keepalived --dont-fork --dump-conf --log-console --log-detail --vrrp &
    # Check if Keepalived is now running by recording it's PID (if it's not running $pid will be null):
    pid=$(pidof keepalived)

    # If $pid is null, startup failed; log the fact and sleep for 2s
    # We'll then automatically loop through and try again
    if [ -z "$pid" ]; then
      echo "Startup of Keepalived failed, sleeping for 2s, then retrying..."
      sleep 2
    fi

  done

  # Break this outer loop once we've started up successfully
  break

done

while true; do

  # Check if Keepalived is STILL running by recording it's PID (if it's not running $pid will be null):
  pid=$(pidof keepalived)
  # If it is not, lets kill our PID1 process (this script) by breaking out of this while loop:
  # This ensures Docker 'sees' the failure and handles it as necessary
  if [ -z "$pid" ]; then
    echo "Keepalived is no longer running, exiting so Docker can restart the container..."
    break
  fi

  # If it is, give the CPU a rest
  sleep 0.5

done

exit 1
