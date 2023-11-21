Go Packages Driver

gopackagesdriver_test
--------------------
Verifies that the output of the go packages driver includes the correct output.

Go x/tools is very sensitive to inaccuracies in the package output, so we should
validate each added feature against what is expected by x/tools.
