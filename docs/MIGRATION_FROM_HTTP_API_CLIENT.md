# Migration from HTTP::API::Client

`HTTP::API::Core` continues the pre-release `HTTP::API::Client` project under a new CPAN namespace.

The rename was required because `HTTP::API::Client` was not available for authorized CPAN indexing.

Replace `use HTTP::API::Client;` with `use HTTP::API::Core;`. Supporting packages move likewise: Auth, Error, Pagination, RateLimit, and Response now live under `HTTP::API::Core::*`.

`HTTP::API::Core` 0.01 carries forward the behavior developed through `HTTP::API::Client` 0.12.
