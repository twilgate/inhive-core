@echo off
set GOOS=windows
set GOARCH=amd64
set CC=x86_64-w64-mingw32-gcc
set CGO_ENABLED=1
go run ./cli tunnel exit
del bin\inhive-core.dll bin\InhiveCli.exe
set CGO_LDFLAGS=
go build -trimpath -tags with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api,with_grpc -ldflags="-w -s" -buildmode=c-shared -o bin/inhive-core.dll ./custom
go get github.com/akavel/rsrc
go install github.com/akavel/rsrc

rsrc  -ico .\assets\hiddify-cli.ico -o cli\bydll\cli.syso

copy bin\inhive-core.dll .
set CGO_LDFLAGS="inhive-core.dll"
go build  -o bin/InhiveCli.exe ./cli/bydll/
del inhive-core.dll
