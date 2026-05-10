// recovery_interceptor.go — gRPC unary/stream interceptors that recover from
// handler panics, log them as FATAL, and surface them to the client as a
// gRPC Internal status. Removes the per-handler `defer config.RecoverPanicToError`
// boilerplate that previously lived in every CoreService method.
package hcore

import (
	"context"
	"fmt"
	"runtime/debug"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func recoveryUnaryInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (resp any, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = status.Errorf(codes.Internal, "%s panic: %v", info.FullMethod, r)
			Log(LogLevel_FATAL, LogType_CORE, fmt.Sprintf("%s panic: %v\n%s", info.FullMethod, r, debug.Stack()))
		}
	}()
	return handler(ctx, req)
}

func recoveryStreamInterceptor(srv any, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = status.Errorf(codes.Internal, "%s panic: %v", info.FullMethod, r)
			Log(LogLevel_FATAL, LogType_CORE, fmt.Sprintf("%s panic: %v\n%s", info.FullMethod, r, debug.Stack()))
		}
	}()
	return handler(srv, ss)
}
