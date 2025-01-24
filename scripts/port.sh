#!/bin/bash

#sysctl net.ipv4.ip_unprivileged_port_start=0

etops portdown $*
sleep 2
etops portup $*
