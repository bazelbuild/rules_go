package grpc_test

import (
	"context"
	"fmt"
	"log"
	"net"
	"testing"

	"example.com/foo_proto"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type fooerServer struct {
}

func newServer() *fooerServer {
	return &fooerServer{}
}

func (*fooerServer) RoundTripFoo(ctx context.Context, foo *foo_proto.Foo) (*foo_proto.Foo, error) {
	foo.Value += 1
	return foo, nil
}

func TestRoundTripFoo(t *testing.T) {
	// Start the server.
	address := fmt.Sprintf("localhost:%d", 12345)
	lis, err := net.Listen("tcp", address)
	if err != nil {
		log.Fatalf("failed to listen on %s: %v", address, err)
	}
	grpcServer := grpc.NewServer()
	foo_proto.RegisterFooerServer(grpcServer, newServer())
	go func() {
		grpcServer.Serve(lis)
	}()

	// Start the client.
	conn, err := grpc.Dial(address, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("fail to dial %s: %v", address, err)
	}
	defer conn.Close()
	client := foo_proto.NewFooerClient(conn)

	// Send a message and verify that it is returned correctly.
	msgIn := &foo_proto.Foo{
		Value: 42,
	}
	msgOut, err := client.RoundTripFoo(context.TODO(), msgIn)
	if err != nil {
		log.Fatalf("failed to round-trip message: %v", err)
	}
	if msgOut.Value != 43 {
		log.Fatalf("message did not round-trip correctly: sent %v, got %v", msgIn, msgOut)
	}

	grpcServer.GracefulStop()
}
