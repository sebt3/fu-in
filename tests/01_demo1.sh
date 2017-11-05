#!/bin/bash
test.declare demo1 demoGroup 3	a simple demonstration test

always_ok.run() {
	true
}
always_ok.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.empty
	assert.stdout.notmatch "*ERROR*"
	assert "[ -f \"$0\" ]" "This script is a file"
	assert "[ -d \"$DIR\" ]" "The test directory exist"
}
test.step demo1 always_ok	a succesfull step

always_failed.run() {
	echo some error>&2
	echo some outout
	return 4
}
always_failed.asserts() {
	assert.rc 0
	assert.notrc 4
	assert.stderr.empty
	assert.stdout.empty
	assert.stdout.match "*success*"
	assert.stderr.notmatch "*error*"
	assert.stderr.match "OK*"
}
test.step demo1 always_failed	a failed step

