package c

/*
int c_live() { return 56; }
int c_dead() { return 78; }
*/
import "C"

func CCgoLive() int {
	return int(C.c_live())
}

func CCgoDead() int {
	return int(C.c_dead())
}
