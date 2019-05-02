#!/bin/sh
#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# 5698-ZWE Copyright Contributors to the Zowe Project. 2019, 2019
#######################################################################

# Set environment variables for Zowe install & configuration.
# Called by zowe-install*.sh
#
# CALLED WITH SHELL SHARING (. script.sh), will exit on error
#
# Arguments:
# /
#
# Expected globals:
# $debug $IgNoRe_ErRoR $inst $conf
#
# Optional globals:
# $INSTALL_DIR $LOG_DIR $LOG_FILE $ZOWE_YAML $ZOWE_ROOT_DIR $ZOWE_HLQ
#
# Unconditional set:
# $_EDC_ADD_ERRNO2  1
# $ENV              (null)
# ZOWE_VERSION      (defined in $INSTALL_DIR/manifest.json)
#
# Conditional set:
# $INSTALL_DIR      $(dirname $0)/..
# $LOG_DIR          $INSTALL_DIR/log
# $LOG_FILE         $LOG_DIR/$(date +%Y-%m-%d-%H-%M-%S).$$.log
# $ZOWE_YAML        $INSTALL_DIR/install/zowe.yaml
# $ZOWE_ROOT_DIR    (defined in $ZOWE_YAML)
# $ZOWE_HLQ         (defined in $ZOWE_YAML)
# when needed, all variables in $ZOWE_YAML, see zowe-parse-yaml.sh
#
# Alters:
# $sTaTuS $saved_ZOWE_ROOT_DIR $saved_ZOWE_HLQ $saved_me
# see also zowe-parse-yaml.sh for other altered environment variables

# Exit during shell sharing will kill the caller without giving it a 
# chance to print any message. Therefore all error messages here 
# include the name of the caller, $(basename $0).

saved_me=$me                   # remember original $me
me=zowe-set-envvars.sh         # no $(basename $0) with shell sharing
#debug=-d                      # -d or null, -d triggers early debug
#IgNoRe_ErRoR=1                # no exit on error when not null  #debug
#set -x                                                          #debug

test "$debug" && echo "> $me $@"
#test "$LOG_FILE" && echo "<$me> $@" >> $LOG_FILE

# ---------------------------------------------------------------------
# --- show & execute command, and bail with message on error
#     stderr is routed to stdout to preserve the order of messages
# $1: if --null then trash stdout, parm is removed when present
# $1: if --save then append stdout to $2, parms are removed when present
# $1: if --repl then save stdout to $2, parms are removed when present
# $2: if $1 = --save or --repl then target receiving stdout
# $@: command with arguments to execute
# ---------------------------------------------------------------------
function _cmd
{
test "$debug" && echo
if test "$1" = "--null"
then         # stdout -> null, stderr -> stdout (without going to null)
  shift
  test "$debug" && echo "$@ 2>&1 >/dev/null"
                         $@ 2>&1 >/dev/null
elif test "$1" = "--save"
then         # stdout -> >>$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 >> $sAvE"
                         $@ 2>&1 >> $sAvE
elif test "$1" = "--repl"
then         # stdout -> >$2, stderr -> stdout (without going to $2)
  sAvE=$2
  shift 2
  test "$debug" && echo "$@ 2>&1 > $sAvE"
                         $@ 2>&1 > $sAvE
else         # stderr -> stdout, caller can add >/dev/null to trash all
  test "$debug" && echo "$@ 2>&1"
                         $@ 2>&1
fi    #
sTaTuS=$?
if test $sTaTuS -ne 0
then
  echo "** ERROR $me '$@' ended with status $sTaTuS"
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #
}    # _cmd

# ---------------------------------------------------------------------
# --- main --- main --- main --- main --- main --- main --- main ---
# ---------------------------------------------------------------------
function main { }     # dummy function to simplify program flow parsing
export _EDC_ADD_ERRNO2=1                        # show details on error
# .profile with ENV=script with echo -> echo is in stdout (begin)
unset ENV

# Base directory from which install/config is happening
if test -z "$INSTALL_DIR"
then
  _cmd cd $(dirname $0)     # roundabout way to ensure path is expanded
  export INSTALL_DIR=$(dirname $PWD)         # result: $(dirname $0)/..
  test "$debug" && echo INSTALL_DIR=$INSTALL_DIR
fi

# ---

# Create a log file with timestamped name in a log folder that scripts
# can write to, to diagnose any install and/or configuration problems.

if test -z "$LOG_FILE"                       # reuse existing log file?
then                                              # create new log file
  # Set LOG_DIR default if needed
  export LOG_DIR=${LOG_DIR:-$INSTALL_DIR/log}
  test "$debug" && echo LOG_DIR=$LOG_DIR

  # Create the log directory if needed, and ensure all can read & write
  _cmd mkdir -p $LOG_DIR
  _cmd chmod a+rwx $LOG_DIR

  # Create the log file (unique name on a single system)
  export LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d-%H-%M-%S).$$.log"
fi    # create new log file

test "$debug" && echo LOG_FILE=$LOG_FILE
_cmd touch $LOG_FILE
_cmd chmod a+rw $LOG_FILE

# Write header to log file
echo "-------------------------------" >> $LOG_FILE
echo "<$me> $@" >> $LOG_FILE
echo "$(uname -Ia) -- $(date)" >> $LOG_FILE
echo "$(id)" >> $LOG_FILE
test "$inst" && echo "Invoked to install Zowe" >> $LOG_FILE
test "$conf" && echo "Invoked to configure Zowe" >> $LOG_FILE

# ---

# Extract Zowe version from manifest.json
# sample input:
#   "version": "1.0.0",
# sed will:
# -n '...p' only print lines that match
# /"version"/ only process lines that have the characters `"version"`
# s/.../\1/ substitute whole line with a marked section of the line
# .*: "     all characters from begin up till last `: "` (inclusive)
# \(        begin marker for section of line
# [^"]*     all characters from current position to first " (exclusive)
# \)        end marker for section of line
# .*        all characters from current position to end of line
# sample output:
# 1.0.0
export ZOWE_VERSION=$(sed -n '/"version"/s/.*: "\([^"]*\).*/\1/p' \
  $INSTALL_DIR/manifest.json)
test "$debug" && echo ZOWE_VERSION=$ZOWE_VERSION
if test -z "$ZOWE_VERSION"
then
  echo "** ERROR $(basename $0) $me failed to determine Zowe version."
  test ! "$IgNoRe_ErRoR" && exit 8                               # EXIT
fi    #

# ---

# Set $ZOWE_YAML default if needed and validate
export ZOWE_YAML=${ZOWE_YAML:-$INSTALL_DIR/install/zowe.yaml}
if test "$conf" -o -z "$ZOWE_ROOT_DIR" -o -z "$ZOWE_HLQ"
then
  if test ! -r "$ZOWE_YAML"
  then
    echo "** ERROR $(basename $0) $me faulty value for -c: $ZOWE_YAML"
    echo "ls -ld \"$ZOWE_YAML\""; ls -ld "$ZOWE_YAML"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    #
  echo ZOWE_YAML=$ZOWE_YAML | tee -a $LOG_FILE
fi    # $ZOWE_YAML needed

# ---

# Pull default for $ZOWE_ROOT_DIR & $ZOWE_HLQ from $ZOWE_YAML if needed
# As side effect, also sets other configuration environment vars

saved_ZOWE_ROOT_DIR="$ZOWE_ROOT_DIR"
saved_ZOWE_HLQ="$ZOWE_HLQ"
# zowe-parse-yaml.sh exports environment vars, so run in current shell
_cmd . $INSTALL_DIR/scripts/zowe-parse-yaml.sh $ZOWE_YAML
# Error details already reported
test $rc -ne 0 -a ! "$IgNoRe_ErRoR" && exit 8                    # EXIT
  
if test "$saved_ZOWE_ROOT_DIR"
then                                     # provided as startup argument
  # Expand references like ~ in startup argument
  saved_ZOWE_ROOT_DIR=$(sh -c "echo $saved_ZOWE_ROOT_DIR")

  # Ensure startup arg and cfg file value for ZOWE_ROOT_DIR match
  if test -z "$conf"
  then   # no config, disregard cfg file value and use startup argument
    export ZOWE_ROOT_DIR="$saved_ZOWE_ROOT_DIR"
  elif test "$saved_ZOWE_ROOT_DIR" != "$ZOWE_ROOT_DIR"
  then
    echo "** ERROR $(basename $0) $me value for -i $saved_ZOWE_ROOT_DIR" \
      "does not match value in -c $ZOWE_YAML, $ZOWE_ROOT_DIR"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    # match startup arg and cfg file
else                                              # no startup argument
  # no action; use cfg file value as there is no startup argument
fi    #
test "$debug" && echo ZOWE_ROOT_DIR=$ZOWE_ROOT_DIR
echo ZOWE_ROOT_DIR=$ZOWE_ROOT_DIR >> $LOG_FILE

if test "$saved_ZOWE_HLQ"
then                                     # provided as startup argument
  # Ensure startup arg and cfg file value for ZOWE_HLQ match
  if test -z "$conf"
  then   # no config, disregard cfg file value and use startup argument
    export ZOWE_HLQ="$saved_ZOWE_HLQ"
  elif test "$saved_ZOWE_HLQ" != "$ZOWE_HLQ"
  then
    echo "** ERROR $(basename $0) $me value for -h $saved_ZOWE_HLQ" \
      "does not match value in -c $ZOWE_YAML, $ZOWE_HLQ"
    test ! "$IgNoRe_ErRoR" && exit 8                             # EXIT
  fi    # match startup arg and cfg file
else                                              # no startup argument
  # no action; use cfg file value as there is no startup argument
fi    #
test "$debug" && echo ZOWE_HLQ=$ZOWE_HLQ
echo ZOWE_HLQ=$ZOWE_HLQ >> $LOG_FILE

# ---

test "$debug" && echo "< $me 0"
echo "</$me> 0" >> $LOG_FILE
me=$orig_me
# no exit, shell sharing with caller
