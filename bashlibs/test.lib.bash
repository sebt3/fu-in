#!/bin/bash
TEST_name=${TEST_name:-"Unknown test set"}
TEST_groups=()
TEST_tests=()
TEST_groupID=()
TEST_desc=()
TEST_priority=()
TEST_duration=()
TEST_asserts=()
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
	if ! is.function ${step}.run;then
		out.error "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}: function ${step}.run is missing, cannot add step \"$step\" as it is incomplete"
		return 1
	fi
	if ! is.function ${step}.asserts;then
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
test.handleOut() {
	gawk -vD=$1 '{print;print D" "$0 >"/dev/fd/6";fflush("/dev/fd/6") }'
}
test.ctrl() {
	# close all non-usefull filedescriptor
	(
		local n
		for n in $(find /proc/$BASHPID/fd -type l -printf '%f\n');do
			((n > 2)) && eval "exec $n>&-"
		done
		eval "$@"
	)
}

test.run() {
	local min_prio=$1
	local grps=$2
	local tsts=$3
	local i j n
	local tst id g f s step desc
	local out err ret ts t_ts a_ts=$(date '+%s') r c
	exec 6> >(while read lvl line;do out.lvl $lvl "$line";done)
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
		local grpRes=0 oldfd
		for j in ${TEST_toRun[@]};do
			tst=${TEST_tests[$j]}
			eval "TEST_${tst}_stepOut=()"
			eval "TEST_${tst}_stepErr=()"
			eval "TEST_${tst}_stepRet=()"
			eval "TEST_${tst}_stepDur=()"
			eval "TEST_${tst}_stepAssFail=()"
			eval "TEST_${tst}_stepAssCnt=()"

			n=$(eval "echo \${#TEST_${tst}_steps[@]}")
			if [ $n -eq 0 ];then
				out.warn "  Test $tst have no steps, skipping"
				continue
			fi
			out.task "  ${TEST_desc[$j]}";out.return NOTICE
			ASSERT_cnt=0;ASSERT_haveFailed=0;t_ts=$(date '+%s')
			for (( s=0; s<$n; s++ ));do
				step=$(eval "echo \${TEST_${tst}_steps[$s]}")
				desc=$(eval "echo \${TEST_${tst}_sdesc[$s]}")
				out.notice "    Running step \"$desc\""
				out.lvl CMD $(typeset -f ${step}.run|awk 'NR>3 {print l} {l=$0}')
				ts=$(date '+%s')
				oldfd=${OUT_fd:-1};
				if [ $oldfd -eq 1 ];then
					exec 4>&1;OUT_fd=4
				elif [ $oldfd -eq 4 ];then
					exec 5>&1;LOG_fd=5
				fi
				eval "$(test.ctrl ${step}.run  2> >(err=$(test.handleOut STDERR); typeset -p err) > >(out=$(test.handleOut STDOUT); typeset -p out); ret=$?; typeset -p ret )"
				if [ $oldfd -eq 1 ];then
					exec >&- >&4;OUT_fd=${oldfd}
				elif [ $oldfd -eq 4 ];then
					exec >&- >&5;LOG_fd=1
				fi
				eval "TEST_${tst}_stepOut[$s]=\"\$out\""
				eval "TEST_${tst}_stepErr[$s]=\"\$err\""
				eval "TEST_${tst}_stepRet[$s]=$ret"
				eval "TEST_${tst}_stepDur[$s]=$(( $(date '+%s') - $ts )) "
				log.lvl RETURN "$ret"
				ASSERT_current_test=$tst
				ASSERT_current_step=$s
				eval "ASSERT_${tst}_${s}_cmd=()"
				eval "ASSERT_${tst}_${s}_assert=()"
				eval "ASSERT_${tst}_${s}_result=()"
				eval "${step}.asserts"
				c=0
				for r in $(eval "echo \${ASSERT_${tst}_${s}_result[@]}");do 
					[ $r -ne 0 ] && c=$(( $c +1 ))
				done
				eval "TEST_${tst}_stepAssFail[$s]=$c"
				eval "TEST_${tst}_stepAssCnt[$s]=$(eval "echo \${#ASSERT_${tst}_${s}_result[@]}")"
			done
			TEST_duration[$j]=$(( $(date '+%s') - $t_ts ))
			TEST_asserts[$j]=$ASSERT_cnt;
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
	exec 6>&-
	TEST_globalDuration=$(( $(date '+%s') - $a_ts ))
}
test.reportJSON() {
	local g t n ns s tst id step desc sdur serr sout sret gs=0 gt na a stp filter
	filter='s/\\/\\\\/g;s/"/\\"/g;$!s/$/\\/'
	echo "{\"name\":\"$TEST_name\", \"duration\":$TEST_globalDuration, \"groups\":["
	for (( g=0; g<${#TEST_groups[@]}; g++ ));do
		[ -z ${TEST_grpRes[$g]} ] && continue
		n=$(eval "echo \${#TEST_${TEST_groups[$g]}_tests[@]}")
		[ $gs -ne 0 ] && printf ',';gs=1
		printf '\t{ "name":"%s", "result":%d, "tests":[\n' "${TEST_groups[$g]}" "${TEST_grpRes[$g]}"
		gt=0
		for (( t=0; t<$n; t++ ));do
			tst=$(eval "echo \${TEST_${TEST_groups[$g]}_tests[$t]}")
			id=$(test.testID $tst)
			[ -z ${TEST_results[$id]} ] && continue
			[ $gt -ne 0 ] && printf '\t,\t'||printf '\t\t';gt=1
			printf '{ "name":"%s", "description":"%s", "duration":%d, "priority":%d, "result":%d, "total":%d, "steps": [\n' "${TEST_tests[$id]}" "${TEST_desc[$id]}" "${TEST_duration[$id]}" "${TEST_priority[$id]}" "${TEST_results[$id]}" "${TEST_asserts[$id]}"
			ns=$(eval "echo \${#TEST_${tst}_steps[@]}")
			for (( s=0; s<$ns; s++ ));do
				stp=$(eval "echo \${TEST_${tst}_steps[$s]}")
				[ $s -ne 0 ] && printf '\t\t,\t'||printf '\t\t\t'
				printf '{ "name":"%s", "description":"%s", "command":"%s", "duration":%d, "stderr":"%s", "stdout":"%s", "return":%d, "assertCnt":%d, "assertFail":%d, "asserts": [\n' \
					"$stp" "$(eval "echo \${TEST_${tst}_sdesc[$s]}"|sed $filter)" \
					"$(typeset -f ${stp}.run|awk 'NR>3 {print l} {l=$0}'|sed $filter)" \
					"$(eval "echo \${TEST_${tst}_stepDur[$s]}")" "$(eval "echo \${TEST_${tst}_stepErr[$s]}"|sed $filter)" \
					"$(eval "echo \${TEST_${tst}_stepOut[$s]}"|sed $filter)" "$(eval "echo \${TEST_${tst}_stepRet[$s]}")" \
					"$(eval "echo \${TEST_${tst}_stepAssCnt[$s]}")" "$(eval "echo \${TEST_${tst}_stepAssFail[$s]}")"
				na=$(eval "echo \${#ASSERT_${tst}_${s}_assert[@]}")
				for (( a=0; a<$na; a++ ));do
					[ $a -ne 0 ] && printf '\t\t\t,\t'||printf '\t\t\t\t'
					printf '{ "description":"%s", "command":"%s", "result":%d }\n' \
						"$(eval "echo \${ASSERT_${tst}_${s}_assert[$a]}"|sed $filter)" \
						"$(eval "echo \${ASSERT_${tst}_${s}_cmd[$a]}"|sed $filter)" \
						"$(eval "echo \${ASSERT_${tst}_${s}_result[$a]}")"
				done
				printf '\t\t\t]}\n'
			done
			printf '\t\t]}\n'
		done
		printf '\t]}\n'
	done
	echo "]}"
}
test.reportText() {
	echo
	local g grpCnt=0 grpFail=0 t tstCnt=0 tstFail=0 a assCnt=0 assFail=0 s stpCnt=0 stpFail=0 n fail
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
		tst=${TEST_tests[$t]}
		n=$(eval "echo \${#TEST_${tst}_steps[@]}")
		for (( s=0; s<$n; s++ ));do
			fail=$(eval "echo \${TEST_${tst}_stepAssFail[$s]}")
			[ ${fail:-0} -ne 0 ] && stpFail=$(( $stpFail +1 ))
		done
		stpCnt=$(( $stpCnt + $n ))
	done
	assCnt=${#ASSERT_results[@]}
	for (( a=0; a<$assCnt; a++ ));do
		[ ${ASSERT_results[$a]} -ne 0 ] && assFail=$(( $assFail + 1 ))
	done
	printf "%-30s   %7s %7s %7s  %6s\n" "" "Total" "Ok" "Failed" "Rate"
	printf "%-30s : %7d %7d %7d  %6s\n" "Groups"  "$grpCnt" "$(( $grpCnt - $grpFail ))" "$grpFail" \
		"$(echo "scale=2; $(( $grpCnt - $grpFail )) * 100 / $grpCnt"|bc)%"
	printf "%-30s : %7d %7d %7d  %6s\n" "Tests"   "$tstCnt" "$(( $tstCnt - $tstFail ))" "$tstFail" \
		"$(echo "scale=2; $(( $tstCnt - $tstFail )) * 100 / $tstCnt"|bc)%"
	printf "%-30s : %7d %7d %7d  %6s\n" "Steps"   "$stpCnt" "$(( $stpCnt - $stpFail ))" "$stpFail" \
		"$(echo "scale=2; $(( $stpCnt - $stpFail )) * 100 / $stpCnt"|bc)%"
	printf "%-30s : %7d %7d %7d  %6s\n" "Asserts" "$assCnt" "$(( $assCnt - $assFail ))" "$assFail" \
		"$(echo "scale=2; $(( $assCnt - $assFail )) * 100 / $assCnt"|bc)%"
	#TODO: list failed tests
}
test.reportXML() {
	local g t n ns s tst id step desc sdur serr sout sret gs=0 gt na a stp filter
	filter='s/\\/\\\\/g;s/"/\\"/g;$!s/$/\\/'
	cat <<ENDXML
<?xml version="1.0" encoding="UTF-8"?>
<testsuites id="test" errors="$ASSERT_haveFailed" name="$TEST_name" tests="${#ASSERT_results[@]}" time="$TEST_globalDuration">
ENDXML
	for (( g=0; g<${#TEST_groups[@]}; g++ ));do
		[ -z ${TEST_grpRes[$g]} ] && continue
		n=$(eval "echo \${#TEST_${TEST_groups[$g]}_tests[@]}")
		for (( t=0; t<$n; t++ ));do
			tst=$(eval "echo \${TEST_${TEST_groups[$g]}_tests[$t]}")
			id=$(test.testID $tst)
			[ -z ${TEST_results[$id]} ] && continue
			echo "    <testsuite id=\"${TEST_tests[$t]}\" errors=\"${TEST_results[$t]}\" hostname=\"$(hostname)\" name=\"${TEST_desc[$t]}\" tests=\"${TEST_asserts[$t]}\" time=\"${TEST_duration[$t]}\">"
			ns=$(eval "echo \${#TEST_${tst}_steps[@]}")
			for (( s=0; s<$ns; s++ ));do
				stp=$(eval "echo \${TEST_${tst}_steps[$s]}")
				na=$(eval "echo \${#ASSERT_${tst}_${s}_assert[@]}")
				cat <<ENDXML
        <testcase id="$stp" assertions="$na" name="$(eval "echo \${TEST_${tst}_sdesc[$s]}"|sed $filter)"  time="${STEP_SEC[$Fi]}">
            <system-out>$(eval "echo \${TEST_${tst}_stepOut[$s]}"|sed $filter)</system-out>
            <system-err>$(eval "echo \${TEST_${tst}_stepErr[$s]}"|sed $filter)</system-err>
ENDXML
				for (( a=0; a<$na; a++ ));do
					gt=$(eval "echo \${ASSERT_${tst}_${s}_result[$a]}")
					[ $gt -ne 0 ] && printf "\t\t<error message=\"$(eval "echo \${ASSERT_${tst}_${s}_assert[$a]}"|sed $filter)\"  type=\"ERROR\"/>\n"
				done
			done
			printf '\t</testcase>\n'
		done
		echo "    </testsuite>"
	done
	echo "</testsuites>"
}
test.reportHTML() {
	cat <<ENDHTML
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Test results for $TEST_name</title>
  <meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">
  <link href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.css" rel="stylesheet">
  <style>$(cat $DATA_dir/test.css)</style>
  <!--[if lt IE 9]>
  <script src="https://oss.maxcdn.com/html5shiv/3.7.3/html5shiv.min.js"></script>
  <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
  <![endif]-->
</head>
<body class=""><div class="container container-full"><div class="row"> <div class="col-md-2 scrollspy"></div><div class="col-md-10"><section class="content"></section></div></div></div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/4.11.0/d3.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/sebt3/d3-bootstrap@0.5.2/dist/d3-bootstrap-withextra.min.js"></script>
<script>$(cat $DATA_dir/test.js)</script>
<script>data = $(test.reportJSON);
d3.select('section.content').call(widget.report().data(data));
d3.select('.scrollspy').call(widget.toc().data(data));</script></body></html>
ENDHTML
}

ASSERT_results=()
assert() {
	eval "ASSERT_${ASSERT_current_test}_${ASSERT_current_step}_cmd+=(\"\$1\")"
	eval "$1"
	local r=$?
	ASSERT_cnt=$(( $ASSERT_cnt + 1 ))
	[ $r -ne 0 ] && ASSERT_haveFailed=$(( $ASSERT_haveFailed + 1 ))
	eval "ASSERT_${ASSERT_current_test}_${ASSERT_current_step}_result+=($r)"
	shift
	if [ $r -eq 0 ];then
		out.lvl ASSERT "      OK: $1"
		eval "ASSERT_${ASSERT_current_test}_${ASSERT_current_step}_assert+=(\"\$1\")"
	else
		out.lvl ASSERT "      FAIL: $2"
		eval "ASSERT_${ASSERT_current_test}_${ASSERT_current_step}_assert+=(\"\$2\")"
	fi
	ASSERT_results+=($r)
	return $r
}
assert.rc() { 		assert "[ \${TEST_${tst}_stepRet[$s]} -eq $1 ]" "${2:-"Return code is $1"}" "${3:-"Return code was expected to be $1"}"; }
assert.notrc() { 	assert "[ \${TEST_${tst}_stepRet[$s]} -ne $1 ]" "${2:-"Return code is not $1"}" "${3:-"Return code shouldnt be $1"}"; }
assert.stderr.empty() { assert "[ -z \"\${TEST_${tst}_stepErr[$s]}\" ]" "${1:-"stderr is empty"}" "${2:-"stderr was expected empty"}"; }
assert.stdout.empty() { assert "[ -z \"\${TEST_${tst}_stepOut[$s]}\" ]" "${1:-"stdout is empty"}" "${2:-"stdout was expected empty"}"; }
assert.stderr.match() { assert "[[ \"\${TEST_${tst}_stepErr[$s]}\" == $1 ]]" "${2:-"stderr match \"$1\""}" "${3:-"stderr should have matched \"$1\""}"; }
assert.stdout.match() { assert "[[ \"\${TEST_${tst}_stepOut[$s]}\" == $1 ]]" "${2:-"stdout match \"$1\""}" "${3:-"stdout should have matched \"$1\""}"; }
assert.stderr.notmatch() { assert "[[ \"\${TEST_${tst}_stepErr[$s]}\" != $1 ]]" "${2:-"stderr dont match \"$1\""}" "${3:-"stderr should NOT have matched \"$1\""}"; }
assert.stdout.notmatch() { assert "[[ \"\${TEST_${tst}_stepOut[$s]}\" != $1 ]]" "${2:-"stdout dont match \"$1\""}" "${3:-"stdout should NOT have matched \"$1\""}"; }
