#!/bin/bash
TEST_groups=()
TEST_tests=()
TEST_groupID=()
TEST_desc=()
TEST_priority=()
TEST_duration=()
TEST_results=()
TEST_grpRes=()
test.declare() {
	local test=$1;shift
	local group=$1;shift
	local priority=$1;shift
	local desc="$*"
	local i g=0
	for (( i=0; i<${#TEST_tests[@]}; i++ ));do
		[[ ${TEST_tests[$i]} == $test ]] && return 0
	done
	for (( i=0; i<${#TEST_groups[@]}; i++ ));do
		[[ ${TEST_groups[$i]} == $group ]] && g=$i
	done
	if [ $g -eq 0 ] && [[ ${TEST_groups[0]} != $group ]];then
		g=${#TEST_groups[@]}
		TEST_groups+=($group)
		args.option GROUP $group "Tests:"
		eval "TEST_${group}_tests=($test)"
	else
		eval "TEST_${group}_tests+=($test)"
	fi
	args.option TST $test "$desc"
	TEST_tests+=($test)
	TEST_groupID+=($g)
	ARGS_desc_GROUP[$g]="${ARGS_desc_GROUP[$g]} $test"
	TEST_priority+=($priority)
	TEST_desc+=("$desc")
	eval "TEST_${test}_steps=()"
	eval "TEST_${test}_sdesc=()"
}
test.step() {
	local test=$1;shift
	local step=$1;shift
	local desc="$*"
	local i t=0
	for (( i=0; i<${#TEST_tests[@]}; i++ ));do
		[[ ${TEST_tests[$i]} == $test ]] && t=$i
	done
	if [ $t -eq 0 ] && [[ ${TEST_tests[0]} != $test ]];then
		out.error "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}: Test $test not found, cannot add step \"$step\""
		return 1
	fi
	if ! typeset -f ${step}.run >/dev/null;then
		out.error "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}: function ${step}.run is missing, cannot add step \"$step\" as it is incomplete"
		return 1
	fi
	if ! typeset -f ${step}.asserts >/dev/null;then
		out.error "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}: function ${step}.asserts is missing, cannot add step \"$step\" as it is incomplete"
		return 1
	fi
	eval "TEST_${test}_steps+=($step)"
	eval "TEST_${test}_sdesc+=('$desc')"
}
test.load() {
	local DIR=$*
	[ ! -d "$DIR" ] && return 1
	local f
	for f in "$DIR"/*.sh;do
		. "$f"
	done
}
test.testID() {
	local i
	for (( i=0; i<${#TEST_tests[@]}; i++ ));do
		if [[ ${TEST_tests[$i]} == $1 ]];then echo $i;return 0;fi
	done
}
test.run() {
	local min_prio=$1
	local grps=$2
	local tsts=$3
	local i j n
	local tst id g f s step desc
	local out err ret ts t_ts
	for (( i=0; i<${#TEST_groups[@]}; i++ ));do
		if [ ! -z "$grps" ];then
			f=0
			for g in $(sed 's/:/ /g'<<<$grps);do
				if [[ ${TEST_groups[$i]} == $g ]];then
					f=1
				fi
			done
			[ $f -eq 0 ] && continue
		fi
		n=$(eval "echo \${#TEST_${TEST_groups[$i]}_tests[@]}")
		TEST_toRun=()
		for (( j=0; j<$n; j++ ));do
			tst=$(eval "echo \${TEST_${TEST_groups[$i]}_tests[$j]}")
			id=$(test.testID $tst)
			[ $min_prio -gt ${TEST_priority[$id]} ] && continue
			if [ ! -z "$tsts" ];then
				f=0
				for g in $(sed 's/:/ /g'<<<$tsts);do
					if [[ $tst == $g ]];then
						f=1
					fi
				done
				[ $f -eq 0 ] && continue
			fi
			TEST_toRun+=($id)
		done
		[ ${#TEST_toRun[@]} -eq 0 ] && continue
		out.task "Running found tests for ${TEST_groups[$i]}";out.return TASK
		local grpRes=0
		for j in ${TEST_toRun[@]};do
			tst=${TEST_tests[$j]}
			eval "TEST_${tst}_stepOut=()"
			eval "TEST_${tst}_stepErr=()"
			eval "TEST_${tst}_stepRet=()"
			eval "TEST_${tst}_stepDur=()"

			n=$(eval "echo \${#TEST_${tst}_steps[@]}")
			if [ $n -eq 0 ];then
				out.warn "  Test $tst have no steps, skipping"
				continue
			fi
			out.task "  ${TEST_desc[$j]}";out.return NOTICE
			ASSERT_haveFailed=0;t_ts=$(date '+%s')
			for (( s=0; s<$n; s++ ));do
				step=$(eval "echo \${TEST_${tst}_steps[$s]}")
				desc=$(eval "echo \${TEST_${tst}_sdesc[$s]}")
				out.notice "    Running step \"$desc\""
				out.lvl CMD ${step}.run
				ts=$(date '+%s')
				eval "$( ${step}.run  2> >(err=$(cat); typeset -p err) > >(out=$(cat); typeset -p out); ret=$?; typeset -p ret )"
				eval "TEST_${tst}_stepOut[$s]=\"\$out\""
				eval "TEST_${tst}_stepErr[$s]=\"\$err\""
				eval "TEST_${tst}_stepRet[$s]=$ret"
				eval "TEST_${tst}_stepDur[$s]=$(( $(date '+%s') - $ts )) "
				log.lvl OUT "$out"
				log.lvl ERR "$err"
				log.lvl RET "$ret"
				ASSERT_current_test=$tst
				ASSERT_current_step=$s
				eval "ASSERT_${tst}_${s}_cmd=()"
				eval "ASSERT_${tst}_${s}_assert=()"
				eval "ASSERT_${tst}_${s}_result=()"
				out.lvl CMD ${step}.asserts
				eval "${step}.asserts"
			done
			TEST_duration[$j]=$(( $(date '+%s') - $t_ts ))
			TEST_results[$j]=$ASSERT_haveFailed;
			if [ $ASSERT_haveFailed -ne 0 ];then
				grpRes=$(( $grpRes + 1 ))
				out.error "  ${TEST_desc[$j]}"
			else
				out.ok "  ${TEST_desc[$j]}"
			fi
		done
		TEST_grpRes[$i]=$grpRes
		out.ok "Running found tests for ${TEST_groups[$i]}"
	done
	#set|egrep ^TEST_
	#set|egrep ^ASSERT_
	#echo
}
test.reportText() {
	echo
	local g grpCnt=0 grpFail=0 t tstCnt=0 tstFail=0 a assCnt=0 assFail=0
	for (( g=0; g<${#TEST_groups[@]}; g++ ));do
		if [ ! -z ${TEST_grpRes[$g]} ];then
			grpCnt=$(( $grpCnt +1 ))
			[ ${TEST_grpRes[$g]} -ne 0 ] && grpFail=$(( $grpFail + 1 ))
		fi
	done
	for (( t=0; t<${#TEST_tests[@]}; t++ ));do
		if [ ! -z ${TEST_results[$t]} ];then
			tstCnt=$(( $tstCnt +1 ))
			[ ${TEST_results[$t]} -ne 0 ] && tstFail=$(( $tstFail + 1 ))
		fi
	done
	assCnt=${#ASSERT_results[@]}
	for (( a=0; a<$assCnt; a++ ));do
		[ ${ASSERT_results[$a]} -ne 0 ] && assFail=$(( $assFail + 1 ))
	done
	printf "%-30s   %7s %7s %7s\n" "" "Total" "Ok" "Failed"
	printf "%-30s : %7d %7d %7d\n" "Groups"  "$grpCnt" "$(( $grpCnt - $grpFail ))" "$grpFail"
	printf "%-30s : %7d %7d %7d\n" "Tests"   "$tstCnt" "$(( $tstCnt - $tstFail ))" "$tstFail"
	printf "%-30s : %7d %7d %7d\n" "Asserts" "$assCnt" "$(( $assCnt - $assFail ))" "$assFail"
}
test.reportXML() {
	:
}
test.reportHTML() {
	:
}

ASSERT_results=()
assert() {
	eval "ASSERT_${ASSERT_current_test}_${ASSERT_current_step}_cmd+=(\"\$1\")"
	eval "$1"
	local r=$?
	[ $r -ne 0 ] && ASSERT_haveFailed=$(( $ASSERT_haveFailed + 1 ))
	eval "ASSERT_${ASSERT_current_test}_${ASSERT_current_step}_result+=($r)"
	shift
	if [ $r -eq 0 ];then
		out.lvl ASSERT "      OK: $*"
	else
		out.lvl ASSERT "      FAIL: $*"
	fi
	eval "ASSERT_${ASSERT_current_test}_${ASSERT_current_step}_assert+=(\"\$*\")"
	ASSERT_results+=($r)
	return $r
}
assert.rc() { 		assert "[ \${TEST_${tst}_stepRet[$s]} -eq $1 ]" "Return code is $1"; }
assert.notrc() { 	assert "[ \${TEST_${tst}_stepRet[$s]} -ne $1 ]" "Return code is not $1"; }
assert.stderr.empty() { assert "[ -z \"\${TEST_${tst}_stepOut[$s]}\" ]" "stderr is empty"; }
assert.stdout.empty() { assert "[ -z \"\${TEST_${tst}_stepErr[$s]}\" ]" "stdout is empty"; }
assert.stderr.match() { assert "[[ \"\${TEST_${tst}_stepErr[$s]}\" == $1 ]]" "stderr match \"$1\""; }
assert.stdout.match() { assert "[[ \"\${TEST_${tst}_stepOut[$s]}\" == $1 ]]" "stdout match \"$1\""; }
assert.stderr.notmatch() { assert "[[ \"\${TEST_${tst}_stepErr[$s]}\" != $1 ]]" "stderr dont match \"$1\""; }
assert.stdout.notmatch() { assert "[[ \"\${TEST_${tst}_stepOut[$s]}\" != $1 ]]" "stdout dont match \"$1\""; }
