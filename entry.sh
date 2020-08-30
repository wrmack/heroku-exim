#!/bin/bash

sed -i "s/placeholder/"$(whoami)"/" /etc/exim4/exim4.conf 

exec "$@"