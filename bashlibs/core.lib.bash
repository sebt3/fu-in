#!/bin/bash

SCRIPT_file=${0##*/}
SCRIPT_name=${SCRIPT_file%.sh}
SCRIPT_path=$(dirname "$(readlink -f "$0")")
is.set() { 	[ ! -z ${!1+x} ]; }
is.number() {	[[ $1 =~ ^-?[0-9]+$ ]]; }
is.function() {	typeset -f $1 >/dev/null; }
is.array() { 	is.set $1 && [[ "$(declare -p $1)" =~ "declare -a" ]]; }

OUT_levels=(NONE FAIL ERROR OK TASK WARNING STDERR NOTICE CMD INFO STDOUT DETAIL ASSERT ALL)
OUT_level=${OUT_level:-STDOUT}
out.levelID() {
	local i
	for (( i=0; i<${#OUT_levels[@]}; i++));do
		if [[ "$1" = "${OUT_levels[$i]}" ]];then
			echo $i
			return
		fi
	done
}
OUT_color=()
OUT_color[$(out.levelID NONE)]="${OUT_color[$(out.levelID NONE)]:-$(tput sgr0)}"
OUT_color[$(out.levelID FAIL)]="${OUT_color[$(out.levelID FAIL)]:-$(tput setb 4;tput setab 1)}"
OUT_color[$(out.levelID ERROR)]="${OUT_color[$(out.levelID ERROR)]:-$(tput setf 4;tput setaf 1)}"
OUT_color[$(out.levelID STDERR)]="${OUT_color[$(out.levelID STDERR )]:-$(tput setf 4;tput setaf 1)}"
OUT_color[$(out.levelID OK)]="${OUT_color[$(out.levelID OK)]:-$(tput setf 2;tput setaf 2)}"
OUT_color[$(out.levelID WARNING)]="${OUT_color[$(out.levelID WARNING)]:-$(tput setf 6;tput setaf 3)}"
OUT_color[$(out.levelID INFO)]="${OUT_color[$(out.levelID INFO)]:-$(tput setf 3;tput setaf 4)}"
OUT_color[$(out.levelID NOTICE)]="${OUT_color[$(out.levelID NOTICE)]:-$(tput setf 5;tput setaf 13)}"
OUT_color[$(out.levelID DETAIL)]="${OUT_color[$(out.levelID DETAIL)]:-$(tput setf 3;tput setaf 11)}"
OUT_color[$(out.levelID ASSERT)]="${OUT_color[$(out.levelID ASSERT)]:-$(tput setf 3;tput setaf 12)}"
OUT_color[$(out.levelID CMD)]="${OUT_color[$(out.levelID CMD)]:-$(tput setf 6;tput setaf 4)}"
OUT_cmd=()
out.init() {
	[ -x /usr/bin/resize ] && eval $(/usr/bin/resize)
	local space="\033[$((${COLUMNS:-80} - 11))G"
	OUT_fd=1
	for lvl in ${OUT_levels[*]};do
		if [[ $lvl = "NONE" || $lvl = "ALL" ]];then continue;fi
		OUT_id=$(out.levelID $lvl)
		case "$lvl" in
		TASK)	OUT_cmd[$OUT_id]="${OUT_cmd[$OUT_id]:-"printf '\\r[ %7s ] %s' \"\" \"\$*\""}";;
		STDOUT)	OUT_cmd[$OUT_id]="${OUT_cmd[$OUT_id]:-"printf '\\r%s\\n' \"\$*\""}";;
		CMD)	OUT_cmd[$OUT_id]="${OUT_cmd[$OUT_id]:-"printf '\\r${OUT_color[$OUT_id]}%s>${OUT_color[$(out.levelID NONE)]} %s\\n' $lvl \"\$*\""}";;
		*)	OUT_cmd[$OUT_id]="${OUT_cmd[$OUT_id]:-"printf '\\r[ ${OUT_color[$OUT_id]}%7s${OUT_color[$(out.levelID NONE)]} ] %s\\n' $lvl \"\$*\""}";;
		esac
	done
	OUT_levelID=$(out.levelID $OUT_level)
	OUT_levelID=${OUT_levelID:-$(out.levelID STDOUT)}
}
out.lvl() {
	local lvl=$1;shift
	local id=$(out.levelID $lvl)
	id=${id:-10}
	local cmd=${OUT_cmd[$id]}
	[ $id -le ${OUT_levelID:-13} ] && eval "${cmd:-"printf '\\r%s\\n' \"\$*\""} >&${OUT_fd:-1}"
	log.lvl "$lvl" "$*"
	return 0
}
out.return() {
	local id=$(out.levelID $1)
	[ ${id:-10} -le ${OUT_levelID:-13} ] && eval "printf '\\n' >&${OUT_fd:-1}"
}
out.put() {	while read line;do out.lvl STDOUT "$line";done; }
out.error() {	out.lvl ERROR "$*"; }
out.ok() {	out.lvl OK "$*"; }
out.warn() {	out.lvl WARNING "$*"; }
out.info() {	out.lvl INFO "$*"; }
out.notice() {	out.lvl NOTICE "$*"; }
out.detail() {	out.lvl DETAIL "$*"; }
out.task() {	out.lvl TASK "$*"; }
out.fail() {	out.lvl FAIL "$*";exit 1; }
out.cmd() {	out.lvl CMD "$*";eval "$*" 2>&1|out.put; test ${PIPESTATUS[0]} -eq 0; }

log.stamp() { date '+%Y%m%d_%H%M%S'; }
log.separator() { local c=${1:-"="};awk -v "V=$c" 'BEGIN{while (c++<80) printf V;printf "\n"}';}
LOG_dir=${LOG_dir:-"$SCRIPT_path"}
LOG_file=${LOG_file:-"${SCRIPT_name}.log.$(log.stamp)"}
LOG_cmd=${LOG_cmd:-'printf "[$(log.stamp) - %-7s ] %s\n" "$lvl" "$text"'}
LOG_level=${LOG_level:-ALL}
LOG_head=(ARGS_cmd USER PWD)
log.lvl() {
	local lvl=$1;shift
	local text="$*"
	local id=$(out.levelID $lvl)
	if [ ${id:-10} -le ${LOG_levelID:-0} ];then
		if [[ "$lvl" = "TASK" ]];then
			[ $OUT_fd -eq 1 ] && log.separator >> $LOG_dir/$LOG_file
			[ $OUT_fd -ne 1 ] && eval "log.separator >&${LOG_fd:-1}"
		fi
		[ $OUT_fd -eq 1 ] && eval "$LOG_cmd" >> $LOG_dir/$LOG_file
		[ $OUT_fd -ne 1 ] && eval "$LOG_cmd  >&${LOG_fd:-1}"
	fi
}
log.start() {
	local i=0
	out.init
	LOG_levelID=$(out.levelID $LOG_level)
	exec 4>&1
	exec 1>>$LOG_dir/$LOG_file 2>&1
	OUT_fd=4
	LOG_fd=1
	log.separator "#"
	for i in ${LOG_head[*]};do
		printf "%-15s : %s\n" "$i" "$(eval echo "\$$i")"
	done
	log.separator "#"
}
log.end() {
	local R=${1:-$?}
	log.separator "#"
	[ $R -ne 0 ] && out.error "This script returned $R" || out.detail "This script succeded"
	log.separator "#"
	exec >&- >&4
	OUT_fd=1
	return $R
}

ARGS_vars=()
ARGS_short=()
ARGS_long=()
ARGS_haveVal=()
ARGS_mandatory=()
ARGS_validate=()
ARGS_option=()
ARGS_desc=()
ARGS_cb=()
ARGS_info=${ARGS_info:-''}
ARGS_cmd="$*"
ARGS_short_cmd=()
ARGS_helpCallback=${ARGS_helpCallback:-""}
args.declare() {
	local ARGS_cnt=${#ARGS_vars[@]}
	ARGS_validate[$ARGS_cnt]="N"
	if [[ $1 == "N" ]] || [[ $1 == "Y" ]];then
		ARGS_validate[$ARGS_cnt]="$1"
		shift
	fi
	LOG_head+=($1)
	ARGS_cb[$ARGS_cnt]=""
	ARGS_vars[$ARGS_cnt]=$1;shift
	ARGS_short[$ARGS_cnt]=$1;shift
	ARGS_long[$ARGS_cnt]=$1;shift
	case $1 in
	Y*|y*|1)	ARGS_haveVal[$ARGS_cnt]='Y';shift;;
	*)		ARGS_haveVal[$ARGS_cnt]='N';eval "${ARGS_vars[$ARGS_cnt]}=N";shift;;
	esac
	case $1 in
	Y*|y*|1)	ARGS_option[$ARGS_cnt]='Y';eval "ARGS_values_${ARGS_vars[$ARGS_cnt]}=();ARGS_desc_${ARGS_vars[$ARGS_cnt]}=()";shift;;
	*)		ARGS_option[$ARGS_cnt]='N';shift;;
	esac
	case $1 in
	Y*|y*|1)	ARGS_mandatory[$ARGS_cnt]='Y';shift;;
	*)		ARGS_mandatory[$ARGS_cnt]='N';shift;;
	esac
	ARGS_desc[$ARGS_cnt]="$*";
}
args.callback() {
	local i v=$1;shift
	for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
		if [[ ${ARGS_vars[$i]} == $v ]];then
			ARGS_cb[$i]="$*"
		fi
	done
}
args.option.declare() {
	local V=$1;shift;
	local s=$1;shift;
	local l=$1;shift;
	local m=$1;shift;
	local c=$1;shift;
	args.declare "$c" "$V" "$s" "$l" Y Y $m "$*"
}
args.option() {
	local A=$1;shift;local V=$1;shift
	eval "ARGS_values_$A+=($V)"
	eval "ARGS_desc_${A}+=('$*')"
}
args.use.help() {
	args.declare ARGS_help       -h --help       N N N Show this help text
}
args.help() {
	local l="$0"
	local s="$0"
	local v=""
	local n=0
	local i=0
	if is.set ARGS_short_cmd;then
		ARGS_tmp=("${ARGS_short_cmd[@]}")
		while is.set ARGS_tmp;do 
			v=${ARGS_tmp[0]};ARGS_tmp=("${ARGS_tmp[@]:1}")
			for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
				if [[ "${ARGS_vars[$i]}" == "$v" ]];then
					if [[ "${ARGS_mandatory[$i]}" = "Y" ]];then
						s="$s $v"
					else
						s="$s [$v]"
					fi
				fi
			done
		done
	fi
	for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
		v="${ARGS_short[$i]}|${ARGS_long[$i]}"
		[[ "${ARGS_haveVal[$i]}" = "Y" ]] && v="$v ${ARGS_vars[$i]}"
		if [[ "${ARGS_mandatory[$i]}" = "Y" ]];then
			l="$l $v"
		else
			l="$l [$v]"
		fi
	done
	[ -n "$ARGS_info" ] && echo "$ARGS_info"
	echo $l
	is.set ARGS_short_cmd && echo $s
	for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
		v="${ARGS_short[$i]}|${ARGS_long[$i]}"
		[[ "${ARGS_haveVal[$i]}" = "Y" ]] && v="$v ${ARGS_vars[$i]}"
		printf "%-25s: %s\n" "$v" "${ARGS_desc[$i]}"
	done
	for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
		if [[ "${ARGS_option[$i]}" = "Y" ]];then
			echo;echo "Available values for ${ARGS_vars[$i]}:";n=0
			for j in $(eval "echo \${ARGS_values_${ARGS_vars[$i]}[*]}");do
				l=$(eval "echo \${ARGS_desc_${ARGS_vars[$i]}[$n]}")
				n=$(( $n +1 ))
				printf "%-25s: %s\n" "$j" "$l"
			done
		fi
	done
	echo
	if [ ! -z "$ARGS_helpCallback" ] && is.function "$ARGS_helpCallback";then
		$ARGS_helpCallback
		echo
	fi
}
args.parse() {
	local f=0
	out.init
	if [ $# -gt 0 ] && [[ "$1" == -* ]];then
		while [ $# -gt 0 ];do
			f=0
			for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
				case "$1" in
				${ARGS_short[$i]}|${ARGS_long[$i]})
					if [[ "${ARGS_vars[$i]}" = "ARGS_help" ]];then
						args.help
						exit 0
					elif [[ "${ARGS_haveVal[$i]}" != "Y" ]];then
						eval "${ARGS_vars[$i]}=Y"
						ARGS_mandatory[$i]='N'
						f=1
					elif [ $# -lt 2 ];then
						out.error "$1 expect a value"
						args.help
						exit 1
					elif [[ "${ARGS_option[$i]}" = "Y" ]] && [[ "${ARGS_validate[$i]}" = "Y" ]];then
						for j in $(eval "echo \${ARGS_values_${ARGS_vars[$i]}[*]}");do
							[[ "$2" = "$j" ]] && f=1
						done
						if [ $f -eq 0 ];then
							out.error "\"$2\" is an invalid value for \"$1\""
							args.help
							exit 1
						fi
						eval "${ARGS_vars[$i]}=\"$2\"";
						ARGS_mandatory[$i]='N'
						shift
					else
						eval "${ARGS_vars[$i]}=\"$2\"";
						ARGS_mandatory[$i]='N'
						f=1
						shift
					fi
					if [[ "${ARGS_cb[$i]}" != "" ]];then
						local v=$(eval echo \$${ARGS_vars[$i]})
						if ! ${ARGS_cb[$i]} $v;then
							out.error "\"$v\" is an invalid value for \"${ARGS_vars[$i]}\""
							args.help
							exit 1
						fi
					fi;;
				esac
			done
			if [ $f -eq 0 ];then
				out.error "Unknown flag \"$1\""
				args.help
				exit 1
			fi
			shift
		done
	elif [ $# -gt 0 ] && is.set ARGS_short_cmd;then
		ARGS_tmp=("${ARGS_short_cmd[@]}")
		while is.set ARGS_tmp;do 
			v=${ARGS_tmp[0]};ARGS_tmp=("${ARGS_tmp[@]:1}")
			for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
				if [[ "${ARGS_vars[$i]}" == "$v" ]];then
					ARGS_mandatory[$i]='N'
					if [[ "${ARGS_option[$i]}" = "Y" ]] && [[ "${ARGS_validate[$i]}" = "Y" ]];then
						f=0
						for j in $(eval "echo \${ARGS_values_${ARGS_vars[$i]}[*]}");do
							[[ "$1" = "$j" ]] && f=1
						done
						if [ $f -eq 0 ];then
							out.error "\"$1\" is an invalid value for \"$v\""
							args.help
							exit 1
						fi
					fi
					if is.set ARGS_tmp;then
						eval "${ARGS_vars[$i]}=\"$1\"";
					else
						eval "${ARGS_vars[$i]}=\"$*\"";
					fi
					shift
				fi
			done
		done
	fi
	f=0
	for (( i=0; i<${#ARGS_vars[@]}; i++ ));do
		if [[ "${ARGS_mandatory[$i]}" = "Y" ]];then
			f=1
			out.error "flag ${ARGS_long[$i]} should be used"
			args.help
			exit 3
		fi
	done
}
