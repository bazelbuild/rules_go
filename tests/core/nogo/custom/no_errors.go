// package noerrors contains no analyzer errors.
package noerrors

import "dep"

func Baz() int {
	dep.D()
	return 1
}
