#!/bin/bash

OUT_level=${OUT_level:-WARNING}
LOG_dir=${LOG_dir:-"./logs"}
SHLIBDIR=${SHLIBDIR:-"$(cd "$(dirname $0)";pwd)/bashlibs"}
. $SHLIBDIR/core.lib.bash
. $SHLIBDIR/test.lib.bash
OUT_dir=${OUT_dir:-"./out"}
OUT_filePrefix=${LOG_file:-"${SCRIPT_name}.$(log.stamp)"}
DIR=${DIR:-"./tests"}
PRI=${PRI:-3}
OUT=${OUT:-"LOG:TEXT"}

ARGS_info="Automated testing for shell scripts"
args.use.help
args.declare DIR -d --test-directory Y N N "Path to the tests (Default: ${DIR})"
args.callback DIR test.load
args.option.declare OUT -o --output N N "Select the output mode (Default: $OUT)"
args.option OUT LOG "Output an execution log file in $LOG_dir"
args.option OUT TEXT "Output an execution summary"
args.option OUT HTML "Output an HTML summary to $OUT_dir"
#args.option OUT XML "Output an XML (maven compatible) to $OUT_dir"
args.declare PRI -p --priority Y N N "Run test below priority level [1..5] (Default: $PRI)"
args.option.declare GROUP -g --group N N "Test group to run"
args.option.declare TST -t --test N N "Test to run"
ARGS_short_cmd+=(DIR PRI GROUP TST)
out.init
test.load $DIR
args.parse "$@"
mkdir -p $LOG_dir $OUT_dir

LOG_started=0
for om in $(sed 's/:/ /g'<<<$OUT);do
	if [[ "$om" == "LOG" ]];then
		log.start
		LOG_started=1
	fi
done
test.run "$PRI" "$GROUP" "$TST"
R=$?
[ $LOG_started -ne 0 ] && log.end $R
for om in $(sed 's/:/ /g'<<<$OUT);do
	[[ "$om" == "TEXT" ]] && test.reportText
	[[ "$om" == "XML"  ]] && test.reportXML >$OUT_dir/${OUT_filePrefix}.xml
	[[ "$om" == "HTML" ]] && test.reportHTML >$OUT_dir/${OUT_filePrefix}.html
done
