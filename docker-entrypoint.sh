#!/bin/sh
#
#
#
#/opt/sliver-server
if [ -f admin1*]
then
  echo "admin already there do nothing"
else
  /opt/sliver-server operator --name admin1 --lhost 127.0.0.1
fi

/opt/sliver-server daemon
