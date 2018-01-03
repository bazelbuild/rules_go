for t in "go version" "GOROOT=" "GOPATH=" "GOARCH=" "GOOS=" "GOBIN="; do
  if ! grep -q "$t" $1; then
    cat "$1"
    echo
    echo
    echo "Failed to find $t in $1"
    exit 1
  fi
done
