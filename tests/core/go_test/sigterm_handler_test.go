package sigterm_handler_test

import (
	"os"
	"os/signal"
	"sync"
	"syscall"
	"testing"
)

func TestRegisterSignalHandler(t *testing.T) {
	called := false
	var wg sync.WaitGroup

	wg.Add(1)

	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGTERM)

	go func() {
		switch <-c {
		case syscall.SIGTERM:
			called = true
			wg.Done()
		}
	}()

	if err := syscall.Kill(os.Getpid(), syscall.SIGTERM); err != nil {
		t.Fatalf("Failed to send SIGTERM: %v", err)
	}
	wg.Wait()

	if !called {
		t.Fatal("Our handler has not run")
	}
}
