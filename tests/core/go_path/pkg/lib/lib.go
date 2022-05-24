package lib

import (
	"C"
	_ "embed" // for go:embed
)

//go:embed embedded_src.txt
var embedded_src string
