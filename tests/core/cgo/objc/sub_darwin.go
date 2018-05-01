package objc

/*
int sub(int a, int b);
*/
import "C"

func Sub(a, b int32) int32 {
	return int32(C.sub(C.int(a), C.int(b)))
}
