package cgo_pthread_flag

/*
#include <pthread.h>

void* f(void* p) {
	*(int*) p = 42;
	return NULL;
}

int callFInBackground() {
	int x;
	pthread_t thread;
	pthread_create(&thread, NULL, f, &x);
	pthread_join(thread, NULL);
	return x;
}
*/
import "C"

// Wrapper for callFInBackground. We don't support using Cgo directly from
// tests yet.
func callFFromGo() int {
	return int(C.callFInBackground())
}
