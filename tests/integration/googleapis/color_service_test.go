// Copyright 2018 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package color_service_test

import (
	"context"
	"net"
	"reflect"
	"testing"

	"github.com/bazelbuild/rules_go/tests/integration/googleapis/color_service"
	cspb "github.com/bazelbuild/rules_go/tests/integration/googleapis/color_service_proto"
	"google.golang.org/genproto/googleapis/type/color"
	"google.golang.org/grpc"
)

func TestColorService(t *testing.T) {
	lis, err := net.Listen("tcp", "127.0.0.1:")
	if err != nil {
		t.Fatal(err)
	}
	grpcServer := grpc.NewServer()
	cspb.RegisterColorServiceServer(grpcServer, color_service.New())
	go grpcServer.Serve(lis)
	defer grpcServer.Stop()

	conn, err := grpc.Dial(lis.Addr().String(), grpc.WithInsecure())
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	client := cspb.NewColorServiceClient(conn)

	_, err = client.SetColor(context.Background(), &cspb.SetColorRequest{
		Name:  "red",
		Color: &color.Color{Red: 1.0},
	})
	if err != nil {
		t.Errorf("SetColor: %v", err)
	}
	resp, err := client.GetColor(context.Background(), &cspb.GetColorRequest{
		Name: "red",
	})
	if err != nil {
		t.Errorf("GetColor: %v", err)
	}
	want := &color.Color{Red: 1.0}
	if !reflect.DeepEqual(resp.Color, want) {
		t.Errorf("got %#v; want %#v", resp.Color, want)
	}
}
