#!/bin/bash
TEST_name="A group of tests"

test.declare all_success demoGroup 3	a simple successfull demonstration test

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
test.step all_success always_ok	a succesfull step
youpi.run() {
	echo youpi
}
youpi.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.notmatch "*ERROR*"
	assert.stdout.match "youpi"
}
test.step all_success youpi	an other succesfull step
cool.run() {
	echo cool
}
cool.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.notmatch "*ERROR*"
	assert.stdout.match "cool"
}
test.step all_success cool	Yet an other succesfull step



test.declare success_all demoGroup 4	an other simple successfull demonstration test

always_ok2.run() {
	true
}
always_ok2.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.empty
	assert.stdout.notmatch "*ERROR*"
	assert "[ -f \"$0\" ]" "This script is a file" "This script is not a file"
	assert "[ -d \"$DIR\" ]" "The test directory exist" "$DIR is not a directory"
}
test.step success_all always_ok2	a succesfull step
youpi2.run() {
	echo youpi
}
youpi2.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.notmatch "*ERROR*"
	assert.stdout.match "youpi"
}
test.step success_all youpi2	an other succesfull step
cool2.run() {
	echo cool
}
cool2.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.notmatch "*ERROR*"
	assert.stdout.match "cool"
}
test.step success_all cool2	Yet an other succesfull step



test.declare demo2 otherGroup 3	A failed demonstration test

full_fail.run() {
	echo some error>&2
	echo some outout
	return 4
}
full_fail.asserts() {
	assert.rc 0
	assert.notrc 4
	assert.stderr.empty
	assert.stderr.notmatch "*error*"
	assert.stderr.match "OK*"
	assert.stdout.empty
	assert.stdout.match "*success*"
}
test.step demo2 full_fail	a failed step
full_fail2.run() {
	echo some error>&2
	echo some outout
	return 4
}
full_fail2.asserts() {
	assert.rc 0
	assert.notrc 4
	assert.stderr.empty
	assert.stderr.notmatch "*error*"
	assert.stderr.match "OK*"
	assert.stdout.empty
	assert.stdout.match "*success*"
}
test.step demo2 full_fail2	a failed step

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

