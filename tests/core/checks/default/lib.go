package lib

func Foo() bool {
	// This redundant boolean expression should trigger a vet error, which is
	// turned on by default.
	a := true
	return a || a
}
