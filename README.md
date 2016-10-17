# statsd

*[Statsd](https://github.com/etsy/statsd) client library in golang.*

[![Master Build Status](https://secure.travis-ci.org/tecnickcom/statsd.png?branch=master)](https://travis-ci.org/tecnickcom/statsd?branch=master)
[![Master Coverage Status](https://coveralls.io/repos/tecnickcom/statsd/badge.svg?branch=master&service=github)](https://coveralls.io/github/tecnickcom/statsd?branch=master)
[![Go Report Card](https://goreportcard.com/badge/github.com/tecnickcom/statsd)](https://goreportcard.com/report/github.com/tecnickcom/statsd)

* **category**    Library
* **author**      Alexandre Cesaro, Nicola Asuni <info@tecnick.com>
* **copyright**   2015 Alexandre Cesaro, 2016 Nicola Asuni - Tecnick.com
* **license**     MIT (see LICENSE)
* **link**        https://github.com/tecnickcom/statsd
* **docs**        https://godoc.org/github.com/tecnickcom/statsd


## Description

statsd is a simple and efficient golang [Statsd](https://github.com/etsy/statsd) client.

This project has been forked and extended from https://github.com/alexcesaro/statsd


## Features

- Supports all StatsD metrics: counter, gauge, timing and set
- Supports InfluxDB and Datadog tags
- Fast and GC-friendly: all functions for sending metrics do not allocate
- Efficient: metrics are buffered by default
- Simple and clean API
- 100% test coverage


## Download

```
go get github.com/tecnickcom/statsd
```

## Quick Start

This project includes a Makefile that allows you to test and build the project in a Linux-compatible system with simple commands.  
All the artifacts and reports produced using this Makefile are stored in the *target* folder.  

To see all available options:
```
make help
```

To test the project inside a Docker container (requires Docker):
```
make dbuild
```

An arbitrary make target can be executed inside a Docker container by specifying the "MAKETARGET" parameter:
```
MAKETARGET='qa' make dbuild
```
The list of make targets can be obtained by typing ```make```


The base Docker building environment is defined in the following Dockerfile:
```
resources/DockerDev/Dockerfile
```

To execute all the default test builds and generate reports in the current environment:
```
make qa
```

To format the code (please use this command before submitting any pull request):
```
make format
```

## Useful Docker commands

To manually create the container you can execute:
```
docker build --tag="tecnickcom/statsddev" .
```

To log into the newly created container:
```
docker run -t -i tecnickcom/statsddev /bin/bash
```

To get the container ID:
```
CONTAINER_ID=`docker ps -a | grep tecnickcom/statsddev | cut -c1-12`
```

To delete the newly created docker container:
```
docker rm -f $CONTAINER_ID
```

To delete the docker image:
```
docker rmi -f tecnickcom/statsddev
```

To delete all containers
```
docker rm $(docker ps -a -q)
```

To delete all images
```
docker rmi $(docker images -q)
```

## Running all tests

Before committing the code, please check if it passes all tests using
```bash
make qa
```

Other make options are available install this library globally and build RPM and DEB packages.
Please check all the available options using `make help`.


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
