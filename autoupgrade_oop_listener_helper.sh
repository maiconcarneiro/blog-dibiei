#!/bin/bash
#
# Script autoupgrade_oop_listener_helper.sh
# Latest version: https://github.com/maiconcarneiro/blog-dibiei/blob/main/oop_listener_helper.sh
#
# Author: Maicon Carneiro (dibiei.blog)
# Last Update: 05/12/2024
#
# This is an auxiliary script to be used in Autoupgrade Tool as "after_action" during Out-Of-Place patching in Standalone servers without Grid Infrastructure.
# The script will capture parameters from Autupgrade context and call the oop_listener_helper.sh script with -move option.
# The oop_listener_helper script will restart the Listener in new ORACLE_HOME after Autoupgrade complete the deploy.
#
# Get the oop_listener_help script here:
#   https://github.com/maiconcarneiro/blog-dibiei/blob/main/oop_listener_helper.sh
#
# For more information about oop_listener_helper script: 
#    https://dibiei.blog/2024/12/05/script-oop_listener_helper-sh-atualizando-o-listener-durante-o-out-of-place-patching/
#
#

# is expected that Autoupgrade tool exports the root log directory as first path in the ORACLE_PATH variable.
AU_DB_DIR=$(echo "$ORACLE_PATH" | awk -F ":" '{print $1}')

# find the latest JOB created by Autoupgrade in the log dir
AU_DB_DIR_JOB=$(ls -d $AU_DB_DIR/[0-9]* | grep -v temp | sort -n | tail -1)

# get the full path of config file used by Autoupgrade tool
AU_DB_CONFIG=$AU_DB_DIR_JOB/patching/autoupgrade.cfg

# get the source and target home path from the config file
AU_DB_SOURCE_HOME=$(grep "source_home" $AU_DB_CONFIG | awk -F "=" '{print $2}')
AU_DB_TARGET_HOME=$(grep "target_home" $AU_DB_CONFIG | awk -F "=" '{print $2}')

# run the oop_listener_helper script with the source and target home defined in Autoupgrade config file
SCRIPT_DIR=$(dirname "$0")
$SCRIPT_DIR/oop_listener_helper.sh -sourcehome $AU_DB_SOURCE_HOME -desthome $AU_DB_TARGET_HOME -listener_home $AU_DB_TARGET_HOME -move
