#!/bin/bash

#
#  file: configure.sh
#  project: OverSight (configure)
#  description: v1.* uninstaller logic
#
#  created by Patrick Wardle
#  copyright (c) 2021 Objective-See. All rights reserved.
#

#auth check
# gotta be root
if [ "${EUID}" -ne 0 ]; then
    echo ""
    echo "ERROR: must be run as root"
    echo ""
    exit -1
fi

#check args
if [ "$#" -ne 2 ] || ! [ "${1}" == "-uninstall" ]; then
    echo ""
    echo "ERROR: invalid arguments"
    echo ""
    exit -1
fi

#dbg msg
echo "uninstalling"
    
#remove application
rm -rf "/Applications/OverSight.app"
    
#remove preferences, etc.
rm -rf "${2}"

killall "OverSight" 2> /dev/null
killall "com.objective-see.OverSight.helper" 2> /dev/null
killall "OverSight Helper" 2> /dev/null

#happy
exit 0
