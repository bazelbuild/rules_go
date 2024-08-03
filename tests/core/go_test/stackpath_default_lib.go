package stackpath_default_lib

func Wrap(cb func() string) string {
	return cb()
}
