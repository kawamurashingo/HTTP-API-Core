# HTTP::API::Core

A small, dependency-light foundation for building JSON HTTP API clients in Perl.

```perl
use HTTP::API::Core;
my $api = HTTP::API::Core->new(base_url => 'https://api.example.com');
my $response = $api->get('/users');
my $data = $response->json;
```

The module provides reusable API-client infrastructure: JSON handling, query parameters, structured errors, retries/backoff/jitter, pagination, rate limits, hooks, authentication helpers, observability, response helpers, idempotency, and a transport adapter contract.

It deliberately does not replace HTTP transports such as HTTP::Tiny, LWP, Mojo::UserAgent, or Furl.
