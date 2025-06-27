//nolint:testableexamples
package statsd_test

import (
	"log"
	"runtime"
	"time"

	"github.com/tecnickcom/statsd"
)

func ping(_ string) {}

func Example() {
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
}

func ExampleClient_Clone() {
	c, err := statsd.New(statsd.Prefix("my_app"))
	if err != nil {
		log.Print(err)
	}

	httpStats := c.Clone(statsd.Prefix("http"))

	httpStats.Increment("foo.bar") // Increments: my_app.http.foo.bar
}

func ExampleAddress() {
	_, err := statsd.New(statsd.Address("192.168.0.5:8126"))
	if err != nil {
		log.Print(err)
	}
}

func ExampleErrorHandler() {
	_, err := statsd.New(statsd.ErrorHandler(func(err error) {
		log.Print(err)
	}))
	if err != nil {
		log.Print(err)
	}
}

func ExampleFlushPeriod() {
	_, err := statsd.New(statsd.FlushPeriod(10 * time.Millisecond))
	if err != nil {
		log.Print(err)
	}
}

func ExampleMaxPacketSize() {
	_, err := statsd.New(statsd.MaxPacketSize(512))
	if err != nil {
		log.Print(err)
	}
}

func ExampleNetwork() {
	// Send metrics using a TCP connection.
	_, err := statsd.New(statsd.Network("tcp"))
	if err != nil {
		log.Print(err)
	}
}

func ExampleTagsFormat() {
	_, err := statsd.New(statsd.TagsFormat(statsd.InfluxDB))
	if err != nil {
		log.Print(err)
	}
}

func ExampleMute() {
	c, err := statsd.New(statsd.Mute(true))
	if err != nil {
		log.Print(err)
	}

	c.Increment("foo.bar") // Does nothing.
}

func ExampleSampleRate() {
	_, err := statsd.New(statsd.SampleRate(0.2)) // Send metrics 20% of the time.
	if err != nil {
		log.Print(err)
	}
}

func ExamplePrefix() {
	c, err := statsd.New(statsd.Prefix("my_app"))
	if err != nil {
		log.Print(err)
	}

	c.Increment("foo.bar") // Increments: my_app.foo.bar
}

func ExampleTags() {
	_, err := statsd.New(
		statsd.TagsFormat(statsd.InfluxDB),
		statsd.Tags("region", "us", "app", "my_app"),
	)
	if err != nil {
		log.Print(err)
	}
}

func ExampleClient_NewTiming() {
	c, err := statsd.New()
	if err != nil {
		log.Print(err)
	}

	// Send a timing metric each time the function is run.
	defer c.NewTiming().Send("homepage.response_time")

	ping("http://example.com/")
}
