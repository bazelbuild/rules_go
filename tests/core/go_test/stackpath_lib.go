package stackpath_lib

func Wrap(cb func() string) string {
	return cb()
}
