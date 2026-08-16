# HTTP::API::Core — Project Direction

> **HTTP::API::Core is a small, dependency-light foundation for building
> production-quality HTTP API clients in Perl.**

Keep the core:

- small;
- boring;
- predictable;
- dependency-light;
- transport-independent;
- production-oriented;
- testable;
- stable.

Prefer broadly reusable API-client primitives over service-specific behavior.

Non-goals include OpenAPI generation, GraphQL-specific clients, complete OAuth
flows, WebSockets, HTTP servers, async runtimes/frameworks, and service-specific
SDK behavior.

Version 1.0 should be based on API maturity, not feature count.
