#!/bin/bash

TASK_target=()
TASK_name=()
#TASK_preCheck=()
TASK_verify=()
TASK_desc=()
TASK_defaultVerify=${TASK_defaultValidate:-"task.verify"}
TASK_translateTarget=${TASK_translateTarget:-"echo"}
TASK_awkFilter=${TASK_awkFilter:-'/No such file or directory/{L=E}'}
task.add() {
	local target=""
	local i=${#TASK_name[@]}
	if ! is.function $1;then
		target=$1;shift
	fi
	if ! is.function $1;then
		out.error "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}: $1 is not a function cannot add that task to the list"
		return 1
	fi
	TASK_name+=($1)
	shift
	TASK_desc[$i]="$*"
	TASK_target[$i]="$target"
	#TODO support precheck
	if is.function ${TASK_name[$i]}.verify;then
		TASK_verify[$i]="${TASK_name[$i]}.verify"
	else
		TASK_verify[$i]="$TASK_defaultVerify"
	fi
}
task.handleOut() {
	gawk -vD=$1 'BEGIN{E="ERROR";W="WARNING"}{print;L=D}'"$TASK_awkFilter"'{print L" "$0 >"/dev/fd/6";fflush("/dev/fd/6") }'
}
task.verify() {
	local r=0 L
	for L in $(gawk -vD=STDOUT 'BEGIN{E="ERROR";W="WARNING"}{L=D}'"$TASK_awkFilter"'{print L}' <<<"$TASK_out"|sort -u);do
		if [[ $L == "ERROR" ]];then
			out.notice "${TASK_name[$TASK_current]} have generated errors on stdout"
			r=3
		fi
	done 
	if ! [ -z "$TASK_err" ];then
		out.notice "${TASK_name[$TASK_current]} have generated errors on stderr"
		r=2
	fi
	if ! [ $TASK_ret -eq 0 ];then
		out.notice "${TASK_name[$TASK_current]} returned $TASK_ret"
		r=1
	fi
	return $r
}
task.list() {
	local i
	printf "[##]_Task__________________Description____________________________________\n"
	for ((i=0;i<${#TASK_name[@]};i++));do
		printf "[%2d] %-21s %s\n" "$i" "${TASK_name[$i]}" "${TASK_desc[$i]}"
	done
}
task.run() {
	local min=${1:-0}
	local max=${2:-$(( ${#TASK_name[@]} - 1 ))}
	local i out err ret oldfd logdf lvl line
	exec 6> >(while read lvl line;do out.lvl $lvl "$line";done)
	for ((i=$min;i<=$max;i++));do
		TASK_current=$i
		out.task "[$i] ${TASK_desc[$i]}"
		if is.function "${TASK_name[$i]}.precheck";then
			eval "${TASK_name[$i]}.precheck";ret=$?;
			if [ $ret -ne 0 ];then
				out.error "precheck for \"${TASK_desc[$i]}\" have failed"
				out.lvl FAIL "[$i] ${TASK_desc[$i]}"
				return $ret
			fi
		fi
		oldfd=${OUT_fd:-1};
		if [ $oldfd -eq 1 ];then
			exec 4>&1;OUT_fd=4
		elif [ $oldfd -eq 4 ];then
			exec 5>&1;LOG_fd=5
		fi
		#TODO add support for TARGET
		eval "$( ${TASK_name[$i]}  2> >(err=$(task.handleOut STDERR); typeset -p err) > >(out=$(task.handleOut STDOUT); typeset -p out); ret=$?; typeset -p ret )"
		if [ $oldfd -eq 1 ];then
			exec >&- >&4;OUT_fd=${oldfd}
		elif [ $oldfd -eq 4 ];then
			exec >&- >&5;LOG_fd=1
		fi
		TASK_out=$out TASK_err=$err TASK_ret=$ret ${TASK_verify[$i]};ret=$?
		if [ $ret -ne 0 ];then
			out.lvl FAIL "[$i] ${TASK_desc[$i]}"
			return $ret
		else
			out.ok "[$i] ${TASK_desc[$i]}"
		fi
	done
	exec 6>&-
	return 0
}
task.script() {
	local i
	MIN=0
	MAX=$(( ${#TASK_name[@]} - 1 ))
	args.declare MIN  -b --begin Vals NoOption NotMandatory "Begin at that task"
	args.declare MAX  -e --end   Vals NoOption NotMandatory "End at that task"
	args.declare ONLY -o --only  Vals NoOption NotMandatory "Only run this step"
	ARGS_helpCallback=task.list
	args.use.help
	args.parse "$@"
	if ! is.number $MIN || ! is.number $MAX;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $MIN && [[ "$MIN" == "${TASK_name[$i]}" ]];then
				MIN=$i
			fi
			if ! is.number $MAX && [[ "$MAX" == "${TASK_name[$i]}" ]];then
				MAX=$i
			fi
		done
	fi
	if ! is.number $MIN || [ $MIN -lt 0 ] || [ $MIN -ge ${#TASK_name[@]} ];then
		out.error "\"$MIN\" is an invalid value for MIN"
		return 1
	fi
	if ! is.number $MAX || [ $MAX -lt 0 ] || [ $MAX -ge ${#TASK_name[@]} ];then
		out.error "\"$MAX\" is an invalid value for MAX"
		return 1
	fi
	if [ ! -z "$ONLY" ] && ! is.number $ONLY;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $ONLY && [[ "$ONLY" == "${TASK_name[$i]}" ]];then
				ONLY=$i
			fi
		done
		if ! is.number $ONLY;then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
	fi
	if [ ! -z "$ONLY" ];then
		if ! is.number $ONLY || [ $ONLY -lt 0 ] || [ $ONLY -ge ${#TASK_name[@]} ];then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
		MIN=$ONLY
		MAX=$ONLY
	fi
	mkdir -p $LOG_dir
	log.start
	task.run "$MIN" "$MAX"
	log.end
}

ACTIVITY_name=()
ACTIVITY_desc=()
act.add() {
	if ! is.function $1;then
		out.warn "\"$1\" is not a function, cannot add as activity"
		return 1
	fi
	local i=${#ACTIVITY_name[@]}
	ACTIVITY_name+=($1)
	shift
	ACTIVITY_desc[$i]="$*"
}
act.add.post() {
	act.add "$@"
	args.option ACT "$@"
}
act.set() {
	if is.function $1;then
		eval "$1"
	elif is.number $1;then
		eval "${ACTIVITY_name[$1]}"
	else
		out.error "Cannot set \"$1\" activity"
		return 1
	fi
	
}
act.script() {
	local i
	local i
	MIN=0
	#MAX=
	args.option.declare ACT -a --activity Mandatory C "Select the activity to run"
	for (( i=0; i<${#ACTIVITY_name[@]}; i++ ));do
		args.option ACT "${ACTIVITY_name[$i]}" "${ACTIVITY_desc[$i]}"
	done
	ARGS_short_cmd=(ACT "${ARGS_short_cmd[@]}")
	args.declare LST  -l --list  NoVal NoOption NotMandatory "List all available tasks"
	args.declare MIN  -b --begin Vals  NoOption NotMandatory "Begin at that task"
	args.declare MAX  -e --end   Vals  NoOption NotMandatory "End at that task"
	args.declare ONLY -o --only  Vals  NoOption NotMandatory "Only run this step"
	args.use.help
	args.parse "$@"
	act.set $ACT
	if ! is.set MAX;then
		MAX=$(( ${#TASK_name[@]} - 1 ))
	fi
	if ! is.number $MIN || ! is.number $MAX;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $MIN && [[ "$MIN" == "${TASK_name[$i]}" ]];then
				MIN=$i
			fi
			if ! is.number $MAX && [[ "$MAX" == "${TASK_name[$i]}" ]];then
				MAX=$i
			fi
		done
	fi
	if ! is.number $MIN || [ $MIN -lt 0 ] || [ $MIN -ge ${#TASK_name[@]} ];then
		out.error "\"$MIN\" is an invalid value for MIN"
		return 1
	fi
	if ! is.number $MAX || [ $MAX -lt 0 ] || [ $MAX -ge ${#TASK_name[@]} ];then
		out.error "\"$MAX\" is an invalid value for MAX"
		return 1
	fi
	if [ ! -z "$ONLY" ] && ! is.number $ONLY;then
		for ((i=0;i<${#TASK_name[@]};i++));do
			if ! is.number $ONLY && [[ "$ONLY" == "${TASK_name[$i]}" ]];then
				ONLY=$i
			fi
		done
		if ! is.number $ONLY;then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
	fi
	if [ ! -z "$ONLY" ];then
		if ! is.number $ONLY || [ $ONLY -lt 0 ] || [ $ONLY -ge ${#TASK_name[@]} ];then
			out.error "\"$ONLY\" is an invalid value for ONLY"
			return 1
		fi
		MIN=$ONLY
		MAX=$ONLY
	fi
	if [[ "$LST" == "Y" ]];then
		echo "Activity \"$ACT\":"
		task.list
		echo
	else
		mkdir -p $LOG_dir
		[ $(out.levelID $LOG_level) -eq 0 ] && log.start
		task.run "$MIN" "$MAX"
		log.end
	fi
}
