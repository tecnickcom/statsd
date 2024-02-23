/*
Package statsd is a simple and efficient StatsD client.

StatsD is a network daemon that listens for statistics and aggregates them to one or more pluggable backend services (e.g., Graphite).

The statsd package provides options to configure the client, such as the target host/port, sampling rate, and tags.
To use different options, you can clone the client using the Clone() method.

The client's methods buffer metrics, and the buffer is flushed either by the background goroutine (every 100ms by default) or when the buffer is full (1440 bytes by default to avoid IP packet fragmentation).
You can disable the background goroutine using the FlushPeriod(0) option and disable buffering using the MaxPacketSize(0) option.

For more information about StatsD, visit the StatsD homepage: https://github.com/etsy/statsd
*/
package statsd
