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

package color_service

import (
	"context"
	"sync"

	cspb "github.com/bazelbuild/rules_go/tests/integration/googleapis/color_service_proto"
	"google.golang.org/genproto/googleapis/rpc/code"
	"google.golang.org/genproto/googleapis/rpc/status"
	"google.golang.org/genproto/googleapis/type/color"
)

type colorServer struct {
	colors sync.Map
}

func New() cspb.ColorServiceServer {
	return &colorServer{}
}

func (s *colorServer) SetColor(ctx context.Context, r *cspb.SetColorRequest) (*cspb.SetColorResponse, error) {
	_, loaded := s.colors.LoadOrStore(r.Name, r.Color)
	if loaded {
		return &cspb.SetColorResponse{Status: &status.Status{Code: int32(code.Code_ALREADY_EXISTS)}}, nil
	}
	return &cspb.SetColorResponse{}, nil
}

func (s *colorServer) GetColor(ctx context.Context, r *cspb.GetColorRequest) (*cspb.GetColorResponse, error) {
	value, ok := s.colors.Load(r.Name)
	if !ok {
		return &cspb.GetColorResponse{Status: &status.Status{Code: int32(code.Code_NOT_FOUND)}}, nil
	}
	return &cspb.GetColorResponse{Color: value.(*color.Color)}, nil
}
