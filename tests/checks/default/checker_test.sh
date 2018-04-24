bindir=$1
pwd
default_checker="${bindir}/external/io_bazel_rules_go/linux_amd64_stripped/default_checker"
if [ -x "${default_checker}" ]; then
	exit 0
fi
echo "error: default checker binary ${default_checker} does not exist"
exit 1
