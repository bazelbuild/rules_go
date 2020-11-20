// Copyright 2020 The Bazel Authors. All rights reserved.
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

package wkt_wrapper_test

import (
	"testing"

	descriptorpb1 "github.com/golang/protobuf/protoc-gen-go/descriptor"
	pluginpb1 "github.com/golang/protobuf/protoc-gen-go/plugin"
	anypb1 "github.com/golang/protobuf/ptypes/any"
	durationpb1 "github.com/golang/protobuf/ptypes/duration"
	emptypb1 "github.com/golang/protobuf/ptypes/empty"
	structpb1 "github.com/golang/protobuf/ptypes/struct"
	timestamppb1 "github.com/golang/protobuf/ptypes/timestamp"
	wrapperspb1 "github.com/golang/protobuf/ptypes/wrappers"
	field_mask1 "google.golang.org/genproto/protobuf/field_mask"
	type1 "google.golang.org/genproto/protobuf/ptype"
	source_context1 "google.golang.org/genproto/protobuf/source_context"
	descriptorpb2 "google.golang.org/protobuf/types/descriptorpb"
	anypb2 "google.golang.org/protobuf/types/known/anypb"
	durationpb2 "google.golang.org/protobuf/types/known/durationpb"
	emptypb2 "google.golang.org/protobuf/types/known/emptypb"
	field_mask2 "google.golang.org/protobuf/types/known/fieldmaskpb"
	source_context2 "google.golang.org/protobuf/types/known/sourcecontextpb"
	structpb2 "google.golang.org/protobuf/types/known/structpb"
	timestamppb2 "google.golang.org/protobuf/types/known/timestamppb"
	type2 "google.golang.org/protobuf/types/known/typepb"
	wrapperspb2 "google.golang.org/protobuf/types/known/wrapperspb"
	pluginpb2 "google.golang.org/protobuf/types/pluginpb"
)

func Test(t *testing.T) {
	var _ *anypb2.Any = (*anypb1.Any)(nil)
	var _ *anypb1.Any = (*anypb2.Any)(nil)
	var _ *pluginpb2.Version = (*pluginpb1.Version)(nil)
	var _ *pluginpb1.Version = (*pluginpb2.Version)(nil)
	var _ *descriptorpb2.DescriptorProto = (*descriptorpb1.DescriptorProto)(nil)
	var _ *descriptorpb1.DescriptorProto = (*descriptorpb2.DescriptorProto)(nil)
	var _ *durationpb2.Duration = (*durationpb1.Duration)(nil)
	var _ *durationpb1.Duration = (*durationpb2.Duration)(nil)
	var _ *emptypb2.Empty = (*emptypb1.Empty)(nil)
	var _ *emptypb1.Empty = (*emptypb2.Empty)(nil)
	var _ *field_mask1.FieldMask = (*field_mask2.FieldMask)(nil)
	var _ *field_mask2.FieldMask = (*field_mask1.FieldMask)(nil)
	var _ *source_context1.SourceContext = (*source_context2.SourceContext)(nil)
	var _ *source_context2.SourceContext = (*source_context1.SourceContext)(nil)
	var _ *structpb2.Struct = (*structpb1.Struct)(nil)
	var _ *structpb1.Struct = (*structpb2.Struct)(nil)
	var _ *timestamppb2.Timestamp = (*timestamppb1.Timestamp)(nil)
	var _ *timestamppb1.Timestamp = (*timestamppb2.Timestamp)(nil)
	var _ *type1.Type = (*type2.Type)(nil)
	var _ *type2.Type = (*type1.Type)(nil)
	var _ *wrapperspb2.BoolValue = (*wrapperspb1.BoolValue)(nil)
	var _ *wrapperspb1.BoolValue = (*wrapperspb2.BoolValue)(nil)
}
