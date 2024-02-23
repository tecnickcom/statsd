# statsd

*[Statsd](https://github.com/etsy/statsd) Go client library*

This project has been originally forked and extended from https://github.com/alexcesaro/statsd

This package is a simple and efficient StatsD client.
StatsD is a network daemon that listens for statistics and aggregates them to one or more pluggable backend services (e.g., Graphite).
For more information about StatsD, visit the StatsD homepage: https://github.com/etsy/statsd

The packages documentation is available at: [https://pkg.go.dev/github.com/tecnickcom/statsd](https://pkg.go.dev/github.com/tecnickcom/statsd)


[![Go Reference](https://pkg.go.dev/badge/github.com/tecnickcom/statsd.svg)](https://pkg.go.dev/github.com/tecnickcom/statsd)   
[![check](https://github.com/tecnickcom/statsd/actions/workflows/check.yaml/badge.svg)](https://github.com/tecnickcom/statsd/actions/workflows/check.yaml)
[![Coverage Status](https://coveralls.io/repos/github/tecnickcom/statsd/badge.svg?branch=main)](https://coveralls.io/github/tecnickcom/statsd?branch=main)
[![Go Report Card](https://goreportcard.com/badge/github.com/tecnickcom/statsd)](https://goreportcard.com/report/github.com/tecnickcom/statsd)

* **category**    Library
* **license**     [MIT](https://github.com/tecnickcom/statsd/blob/main/LICENSE)
* **link**        https://github.com/tecnickcom/statsd

-----------------------------------------------------------------


## Features

- Supports all StatsD metrics: counter, gauge, timing and set
- Supports InfluxDB and Datadog tags
- Fast and GC-friendly: all functions for sending metrics do not allocate
- Efficient: metrics are buffered by default
- Simple and clean API
- 100% test coverage

-----------------------------------------------------------------

<a name="quickstart"></a>
## Developers' Quick Start

To quickly get started with this project, follow these steps:

1. Ensure you have installed the latest Go version.
1. Clone the repository: `git clone https://github.com/tecnickcom/statsd.git`.
2. Change into the project directory: `cd statsd`.
3. Install the required dependencies and test everything: `DEVMODE=LOCAL make x`.

Now you are ready to start developing with statsd!

This project includes a *Makefile* that allows you to test and build the project in a Linux-compatible system with simple commands.  
All the artifacts and reports produced using this *Makefile* are stored in the *target* folder.  

Alternatively, everything can be built inside a [Docker](https://www.docker.com) container using the command `make dbuild` that uses the environment defined at `resources/docker/Dockerfile.dev`.

To see all available options:
```bash
make help
```

-----------------------------------------------------------------

<a name="runtest"></a>
## Running all tests

Before committing the code, please format it and check if it passes all tests using
```bash
DEVMODE=LOCAL make x
```

-----------------------------------------------------------------

## Example
```
c, err := statsd.New() // Connect to the UDP port 8125 by default.
if err != nil {
    // If nothing is listening on the target port, an error is returned and
    // the returned client does nothing but is still usable. So we can
    // just log the error and go on.
    log.Print(err)
}
defer c.Close()

// Increment a counter.
c.Increment("foo.counter")

// Gauge something.
c.Gauge("num_goroutine", runtime.NumGoroutine())

// Time something.
t := c.NewTiming()
ping("http://example.com/")
t.Send("homepage.response_time")

// It can also be used as a one-liner to easily time a function.
pingHomepage := func() {
    defer c.NewTiming().Send("homepage.response_time")

    ping("http://example.com/")
}
pingHomepage()

// Cloning a Client allows using different parameters while still using the
// same connection.
// This is way cheaper and more efficient than using New().
stat := c.Clone(statsd.Prefix("http"), statsd.SampleRate(0.2))
stat.Increment("view") // Increments http.view
```
