module github.com/tecnickcom/statsd

go 1.25

toolchain go1.25.0

retract v2.0.6+incompatible // Published in error - v1 is the current version

tool go.uber.org/mock/mockgen

require github.com/golang/mock v1.6.0

require (
	go.uber.org/mock v0.5.2 // indirect
	golang.org/x/mod v0.18.0 // indirect
	golang.org/x/sync v0.7.0 // indirect
	golang.org/x/tools v0.22.0 // indirect
)
