package cgo

import (
	"C"
	"runtime"
)

//export goVersion
func goVersion() string {
	return runtime.Version()
}
