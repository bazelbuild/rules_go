package main

import (
	"log"
	"net"

	pb "github.com/bazelbuild/rules_go/examples/proto/grpc/my_svc_proto"
	lpb "github.com/bazelbuild/rules_go/examples/proto/lib/lib_proto"
	apb "github.com/golang/protobuf/ptypes/any"
	epb "github.com/golang/protobuf/ptypes/empty"
	"golang.org/x/net/context"
	"google.golang.org/grpc"
)

type server struct{}

func (s *server) Get(ctx context.Context, req *pb.GetRequest) (*epb.Empty, error) {
	return &epb.Empty{}, nil
}

func (s *server) Put(ctx context.Context, req *apb.Any) (*lpb.LibObject, error) {
	return &lpb.LibObject{}, nil
}

func main() {
	lis, err := net.Listen("tcp", ":8080")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := grpc.NewServer()
	pb.RegisterMyServiceServer(s, &server{})
	s.Serve(lis)
}
