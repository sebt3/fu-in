#!/bin/bash
TEST_name="A group of tests"


test.declare demo1 demoGroup 3	a simple demonstration test

always_ok.run() {
	true
}
always_ok.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.empty
	assert.stdout.notmatch "*ERROR*"
	assert "[ -f \"$0\" ]" "This script is a file" "This script is not a file"
	assert "[ -d \"$DIR\" ]" "The test directory exist" "$DIR is not a directory"
}
test.step demo1 always_ok	a succesfull step



test.declare demo2 demoGroup 3	A failed demonstration test

always_failed1.run() {
	echo some error>&2
	echo some outout
	return 4
}
always_failed1.asserts() {
	assert.rc 0
	assert.notrc 4
	assert.stderr.empty
	assert.stderr.notmatch "*error*"
	assert.stderr.match "OK*"
	assert.stdout.empty
	assert.stdout.match "*success*"
}
test.step demo2 always_failed1	a failed step

always_failed2.run() {
	LANG=C cp /some/non/existing/file /to/some/non/existing/dir
}
always_failed2.asserts() {
	assert.rc 0
	assert.notrc 1
	assert.stderr.empty
	assert.stderr.notmatch "*No\ such\ file\ or\ directory*"
}
test.step demo2 always_failed2	an other failed step

