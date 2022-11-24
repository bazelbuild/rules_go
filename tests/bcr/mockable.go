package mockable

import "net/url"

type Client interface {
	Connect(addr string) url.URL
}
