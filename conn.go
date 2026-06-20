package statsd

import (
	"fmt"
	"io"
	"math/rand"
	"net"
	"strconv"
	"sync"
	"time"
)

// Stubbed out for testing.
//
//nolint:gochecknoglobals
var (
	dialTimeout = net.DialTimeout
	now         = time.Now
	randFloat   = rand.Float32
)

type conn struct {
	// Fields settable with options at Client's creation.
	addr          string
	errorHandler  func(error)
	flushPeriod   time.Duration
	maxPacketSize int
	network       string
	tagFormat     TagFormat
	mu            sync.Mutex

	// Channels used to stop the background flush goroutine and wait for its
	// exit. They are nil when no flush goroutine is running.
	stop chan struct{}
	done chan struct{}

	// Fields guarded by the mutex.
	closed    bool
	w         io.WriteCloser
	buf       []byte
	rateCache map[float32]string
}

func newConn(conf connConfig, muted bool) (*conn, error) {
	c := &conn{
		addr:          conf.Addr,
		errorHandler:  conf.ErrorHandler,
		flushPeriod:   conf.FlushPeriod,
		maxPacketSize: conf.MaxPacketSize,
		network:       conf.Network,
		tagFormat:     conf.TagFormat,
	}

	// A negative maximum packet size is meaningless and would make the buffer
	// allocation below panic, so treat it like 0 (buffering disabled).
	if c.maxPacketSize < 0 {
		c.maxPacketSize = 0
	}

	if muted {
		return c, nil
	}

	var err error

	c.w, err = dialTimeout(c.network, c.addr, 5*time.Second)
	if err != nil {
		return c, err
	}

	// To prevent a buffer overflow add some capacity to the buffer to allow for
	// an additional metric.
	c.buf = make([]byte, 0, c.maxPacketSize+200)

	if c.flushPeriod > 0 {
		c.stop = make(chan struct{})
		c.done = make(chan struct{})

		go c.flushLoop()
	}

	return c, nil
}

// flushLoop periodically flushes the buffer until stopFlushLoop is called.
func (c *conn) flushLoop() {
	ticker := time.NewTicker(c.flushPeriod)

	defer ticker.Stop()
	defer close(c.done)

	for {
		select {
		case <-c.stop:
			return
		case <-ticker.C:
			c.mu.Lock()
			c.flush(0)
			c.mu.Unlock()
		}
	}
}

// stopFlushLoop stops the background flush goroutine, if any, and waits for it
// to exit. It must be called without holding the mutex.
func (c *conn) stopFlushLoop() {
	if c.flushPeriod > 0 {
		close(c.stop)
		<-c.done
	}
}

func (c *conn) metric(prefix, bucket string, n any, typ string, rate float32, tags string) {
	c.mu.Lock()

	l := len(c.buf)

	c.appendBucket(prefix, bucket, tags)

	if !c.appendNumber(n) {
		c.buf = c.buf[:l] // roll back the partial metric
		c.handleError(fmt.Errorf("statsd: unsupported value type %T for bucket %q", n, bucket))
		c.mu.Unlock()

		return
	}

	c.appendType(typ)
	c.appendRate(rate)
	c.closeMetric(tags)
	c.flushIfBufferFull(l)
	c.mu.Unlock()
}

func (c *conn) gauge(prefix, bucket string, value any, tags string) {
	c.mu.Lock()

	l := len(c.buf)

	// To set a gauge to a negative value we must first set it to 0.
	// https://github.com/etsy/statsd/blob/master/docs/metric_types.md#gauges
	if isNegative(value) {
		c.appendBucket(prefix, bucket, tags)
		_ = c.appendGauge(0, tags) // 0 is always a supported value
	}

	c.appendBucket(prefix, bucket, tags)

	if !c.appendGauge(value, tags) {
		c.buf = c.buf[:l] // roll back the partial metric
		c.handleError(fmt.Errorf("statsd: unsupported value type %T for bucket %q", value, bucket))
		c.mu.Unlock()

		return
	}

	c.flushIfBufferFull(l)
	c.mu.Unlock()
}

func (c *conn) appendGauge(value any, tags string) bool {
	if !c.appendNumber(value) {
		return false
	}

	c.appendType("g")
	c.closeMetric(tags)

	return true
}

func (c *conn) unique(prefix, bucket string, value string, tags string) {
	c.mu.Lock()
	l := len(c.buf)
	c.appendBucket(prefix, bucket, tags)
	c.appendString(value)
	c.appendType("s")
	c.closeMetric(tags)
	c.flushIfBufferFull(l)
	c.mu.Unlock()
}

func (c *conn) appendByte(b byte) {
	c.buf = append(c.buf, b)
}

func (c *conn) appendString(s string) {
	c.buf = append(c.buf, s...)
}

// numKind identifies the kind of a normalized numeric value.
type numKind uint8

const (
	numNone numKind = iota // unsupported type
	numInt
	numUint
	numFloat32
	numFloat64
)

// number normalizes a supported numeric value into an int64, uint64 or float64
// together with its kind. The kind is numNone for unsupported types. It is the
// single source of truth for the set of supported types.
//
//nolint:gocyclo,cyclop
func number(v any) (int64, uint64, float64, numKind) {
	switch n := v.(type) {
	case int:
		return int64(n), 0, 0, numInt
	case uint:
		return 0, uint64(n), 0, numUint
	case int64:
		return n, 0, 0, numInt
	case uint64:
		return 0, n, 0, numUint
	case int32:
		return int64(n), 0, 0, numInt
	case uint32:
		return 0, uint64(n), 0, numUint
	case int16:
		return int64(n), 0, 0, numInt
	case uint16:
		return 0, uint64(n), 0, numUint
	case int8:
		return int64(n), 0, 0, numInt
	case uint8:
		return 0, uint64(n), 0, numUint
	case float64:
		return 0, 0, n, numFloat64
	case float32:
		return 0, 0, float64(n), numFloat32
	default:
		return 0, 0, 0, numNone
	}
}

// appendNumber appends the textual representation of a supported numeric value
// to the buffer. It returns false (appending nothing) for unsupported types.
func (c *conn) appendNumber(v any) bool {
	i, u, f, kind := number(v)

	switch kind {
	case numInt:
		c.buf = strconv.AppendInt(c.buf, i, 10)
	case numUint:
		c.buf = strconv.AppendUint(c.buf, u, 10)
	case numFloat32:
		c.buf = strconv.AppendFloat(c.buf, f, 'f', -1, 32)
	case numFloat64:
		c.buf = strconv.AppendFloat(c.buf, f, 'f', -1, 64)
	case numNone:
		return false
	}

	return true
}

// isNegative reports whether v is a supported numeric value that is negative.
func isNegative(v any) bool {
	i, _, f, kind := number(v)

	negative := false

	switch kind {
	case numInt:
		negative = i < 0
	case numFloat32, numFloat64:
		negative = f < 0
	case numUint, numNone:
		// unsigned integers and unsupported types are never negative
	}

	return negative
}

func (c *conn) appendBucket(prefix, bucket string, tags string) {
	c.appendString(prefix)
	c.appendString(bucket)

	if c.tagFormat == InfluxDB {
		c.appendString(tags)
	}

	c.appendByte(':')
}

func (c *conn) appendType(t string) {
	c.appendByte('|')
	c.appendString(t)
}

func (c *conn) appendRate(rate float32) {
	if rate == 1 {
		return
	}

	if c.rateCache == nil {
		c.rateCache = make(map[float32]string)
	}

	c.appendString("|@")

	if s, ok := c.rateCache[rate]; ok {
		c.appendString(s)
	} else {
		s = strconv.FormatFloat(float64(rate), 'f', -1, 32)
		c.rateCache[rate] = s
		c.appendString(s)
	}
}

func (c *conn) closeMetric(tags string) {
	if c.tagFormat == Datadog {
		c.appendString(tags)
	}

	c.appendByte('\n')
}

func (c *conn) flushIfBufferFull(lastSafeLen int) {
	if len(c.buf) > c.maxPacketSize {
		c.flush(lastSafeLen)
	}
}

// flush flushes the first n bytes of the buffer.
// If n is 0, the whole buffer is flushed.
func (c *conn) flush(n int) {
	if len(c.buf) == 0 {
		return
	}

	if n == 0 {
		n = len(c.buf)
	}

	// Trim the last \n, StatsD does not like it.
	_, err := c.w.Write(c.buf[:n-1])

	c.handleError(err)

	if n < len(c.buf) {
		copy(c.buf, c.buf[n:])
	}

	c.buf = c.buf[:len(c.buf)-n]
}

func (c *conn) handleError(err error) {
	if err != nil && c.errorHandler != nil {
		c.errorHandler(err)
	}
}
