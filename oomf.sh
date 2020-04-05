#!/bin/bash

DEBUG=on
OOMFDIR=$(dirname "$0")
PROJECTDIR=$(pwd)
WSD_HTTP_ROOT=$OOMFDIR/frontend
WSD_PORT=8080
OPENOCD_PORT=4444
EXE_EXT=
GUI_OPEN=
HAS_SHUTDOWN=false

[[ $(uname -s) =~ "MINGW" ]] && { WINDOWS=true; EXE_EXT=.exe; GUI_OPEN=start; }
[[ $(uname -s) =~ "Linux" ]] && { LINUX=true; GUI_OPEN=xdg-open; }
[[ $(uname -s) =~ "Darwin" ]] && { MACOS=true; GUI_OPEN=open; }

dbgprint()
{
	[[ $DEBUG ]] && echo $1
}

is_yes()
{
	[ "$1" == "1" ] && return 0
	[ "$1" == "yes" ] && return 0
	return 1
}

check_dependency() {
	declare name=$1$EXE_EXT
	declare ex_path=$2
	retval=$ex_path/$name
	test -f $retval && return 0
	retval=$(command -v $name) && return 0
	return 1
}

openocd_command() {
	retval=
}

shutdown() {
	# only call this function once
	$HAS_SHUTDOWN && return
	HAS_SHUTDOWN=true
	rm -rf $TMPDIR
	echo "Removed temp folder at $TMPDIR."
	echo "Shutting down."
}

gen_interface()
{
	IS_TMPDIR=$(find /tmp/oomf* -maxdepth 0 2> /dev/null) && { echo "found temp directory at $IS_TMPDIR! don't run multiple instances of this script."; exit 1; }
	TMPDIR=/tmp/oomf_$$
	echo "creating temp directory at $TMPDIR."
	echo "populating source files."
	cp -r $OOMFDIR/frontend $TMPDIR
	pushd . > /dev/null
	cd $TMPDIR
	oocmd=""
	ooargs=""
	is_yes $OPENOCD_NEEDS_SUDO && oocmd="sudo "
	oocmd+=$OPENOCD_PATH
	echo "oocmd=\"$oocmd\"" >> oomf_env.sh
	[[ -d $OPENOCD_SCRIPTS_ROOT ]] && ooargs+=" -s $OPENOCD_SCRIPTS_ROOT "
	[[ -d "$PROJECTDIR/cfg" ]] && ooargs+=" -s $PROJECTDIR/cfg "
	ooargs+=$OPENOCD_ARGS
	echo "ooargs=\"$ooargs\"" >> oomf_env.sh
	popd > /dev/null
}

source $OOMFDIR/oomf.config
echo "using default config file from:" $OOMFDIR/oomf.config

if [ -f "$HOME/oomf.config" ]; then
	echo "using user config file from:" $HOME/oomf.config
	source $HOME/oomf.config
fi

if [ -f "$PROJECTDIR/project.config" ]; then
	echo "using project config file from:" $PROJECTDIR/project.config
	source project.config
fi

check_dependency openocd $OPENOCD_LOCATION || { echo "openocd not found! please add it to your path or specify its location in a config file!"; exit 1; }
OPENOCD_PATH=$retval
echo "using openocd at $retval"

check_dependency websocketd $WEBSOCKETD_LOCATION || { echo "websocketd not found! please add it to your path or specify its location in a config file!"; exit 1; }

echo "using websocketd at $retval"
WEBSOCKETD_PATH=$retval

gen_interface

WEBSOCKETD_ARGS+="--port=$WSD_PORT "
WEBSOCKETD_ARGS+="--devconsole "
#WEBSOCKETD_ARGS+="--staticdir=$WSD_HTTP_ROOT "
[[ $WINDOWS ]] && WEBSOCKETD_ARGS+="bash "
WEBSOCKETD_ARGS+="$TMPDIR/run.sh"
wscmd="$WEBSOCKETD_PATH $WEBSOCKETD_ARGS"

echo
echo "Running: $wscmd"
echo

trap shutdown INT TERM ERR EXIT

$GUI_OPEN "http://127.0.0.1:$WSD_PORT" 2> /dev/null
$wscmd 
