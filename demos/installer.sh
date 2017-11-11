#!/bin/bash

OUT_level=${OUT_level:-NOTICE}
BASE_dir=${BASE_dir:-"$(dirname "$(cd "$(dirname $0)";pwd)")"}
LOG_dir=${LOG_dir:-"${BASE_dir}/logs"}
SHLIBDIR=${SHLIBDIR:-"${BASE_dir}/bashlibs"}
. $SHLIBDIR/core.lib.bash
. $SHLIBDIR/task.lib.bash

ARGS_info="demo installer : demo the some of the capability of the task.* module"
DEST=${DEST:-"/tmp/target"}
args.declare DEST -d --destination Y N N "Path to install to"
ARGS_short_cmd+=(DEST)

# these validations can be skiped
verify() {
	if [ "$(id -u)" != "0" ];then
		out.error "This script should be run by root"
		return 1
	fi
	# More validation here
	return 0
}
task.add verify "Check prereqs"



setup() {
	out.warn setup function is running
	mkdir -p "$DEST"
}
setup.verify() {
	$TASK_defaultVerify
	local r=$?
	if ! [ -d "$DEST" ];then
		out.notice "Failed to create target directory: $DEST"
		r=3
	fi
	return $r
	
	
}
task.add setup "Setup the directory"



install() {
	cp "$0" "$DEST"
}
install.verify() {
	$TASK_defaultVerify
	local r=$?
	if ! [ -f "$DEST/$(basename $0)" ];then
		out.notice "Failed to install file $(basename $0) to $DEST"
		r=3
	fi
	return $r
}
task.add install "Copy the files"



extra() {
	:
}
task.add extra "Some extra step"



failed() {
	cp "$0" "/non/existing/$DEST"
}
task.add failed "Some extra step that will fail"



task.script "$@"
