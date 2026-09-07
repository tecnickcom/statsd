// Build tools for the statsd repository, declared in a separate module so that
// they stay out of the module graph of anything importing statsd.
// Installed into target/binutil by "make gotools".
module github.com/tecnickcom/statsd/resources/tools

go 1.25.0

tool (
	github.com/jstemmer/go-junit-report/v2
	go.uber.org/mock/mockgen
)

require (
	github.com/jstemmer/go-junit-report/v2 v2.1.0 // indirect
	go.uber.org/mock v0.6.0 // indirect
	golang.org/x/mod v0.40.0 // indirect
	golang.org/x/sync v0.22.0 // indirect
	golang.org/x/tools v0.49.0 // indirect
)
