#!/bin/bash

OUT_level=${OUT_level:-NOTICE}
BASE_dir=${BASE_dir:-"$(dirname "$(cd "$(dirname $0)";pwd)")"}
LOG_dir=${LOG_dir:-"${BASE_dir}/logs"}
SHLIBDIR=${SHLIBDIR:-"${BASE_dir}/bashlibs"}
. $SHLIBDIR/core.lib.bash
. $SHLIBDIR/task.lib.bash

ARGS_info="demo operate : demo the some of the capability of the act.* module"
args.declare INST -i --instance Y N Y "the instance to operate"
ARGS_short_cmd+=(INST)

create.step1() {
	out.return NOTICE
	out.notice $INST
}
create.step2() {
	:
}
create.step3() {
	:
}
create.step4() {
	:
}
create() {
	task.add create.step1 "Step 1 to create an instance"
	task.add create.step2 "Step 2 to create an instance"
	task.add create.step3 "Step 3 to create an instance"
	task.add create.step4 "Step 4 to create an instance"
}
act.add create "Create an instance"



delete.step1() {
	:
}
delete.step2() {
	:
}
delete.step3() {
	:
}
delete.step4() {
	:
}
delete() {
	task.add delete.step1 "Step 1 to delete an instance"
	task.add delete.step2 "Step 2 to delete an instance"
	task.add delete.step3 "Step 3 to delete an instance"
	task.add delete.step4 "Step 4 to delete an instance"
}
act.add delete "Delete an instance"


act.script "$@"
