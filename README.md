# fu-in
## Overview
fu-in is a bash script to automate testing of commands. It produce tests reports in various format (html, json, xml...) and integrate nicely with Jenkins.
Each fu-in test is part of a group and have a priority level to allow selective testing.
A single test can have a number of steps and each of these steps will be verified.
Tests are loaded from shell scripts in a test directory.

```
Automated testing for shell scripts
./fu-in [-h|--help] [-d|--test-directory DIR] [-o|--output OUT] [-p|--priority PRI] [-g|--group GROUP] [-t|--test TST]
./fu-in [DIR] [PRI] [GROUP] [TST]
-h|--help                : Show this help text
-d|--test-directory DIR  : Path to the tests (Default: ./tests)
-o|--output OUT          : Select the output mode (Default: LOG:TEXT)
-p|--priority PRI        : Run test below priority level [1..5] (Default: 3)
-g|--group GROUP         : Test group to run
-t|--test TST            : Test to run

Available values for OUT (Select the output mode (Default: LOG:TEXT)):
LOG                      : Output an execution log file in ./logs
TEXT                     : Output an execution summary
HTML                     : Output an HTML summary to ./out
JSON                     : Output a JSON summary to ./out
XML                      : Output an XML (JUnit compatible) to ./out
```

## the simplest test

```
test.declare simple demoGroup 3  	The description of the simple test

simple_true.run() {
	true
}
simple_true.asserts() {
	assert.rc 0
	assert.stderr.empty
	assert.stdout.empty
}
test.step simple simple_true	The true step description
```
On the first line, we declare a test named "simple" part of the group "demoGroup" with a priotiry level of "3".
On the last line we associate the step "simple_true" to the "simple" test.

The step is to run the command "true" and then the verification are :
- verify that the return code is 0
- verify that there was no error output
- verify that there was no output

See the tests in the tests directory for more examples.

## Available asserts

| asserts | args | Description |
| --- | --- | --- |
| assert | <test> <OK description> <ERR description> | Generic assert that test for a given shell test |
| assert.rc | <rc> | Validate that the return code was the expected value |
| assert.notrc | <rc> | Validate that the return code was not the forbidden value |
| assert.stderr.empty |  | Verify that there was no ouput on STDERR |
| assert.stdout.empty |  | Verify that there was no ouput on STDOUT |
| assert.stderr.match | <string> | Check if stderr output match the given string |
| assert.stdout.match | <string> | Check if the output match the given string |
| assert.stderr.notmatch | <string> | Check if stderr output contain the forbidden string |
| assert.stdout.notmatch | <string> | Check if the output contain the forbidden string |
