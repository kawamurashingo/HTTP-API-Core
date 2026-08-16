# Authentication helpers

`HTTP::API::Core::Auth` provides small `before_request` hook helpers for authentication schemes commonly used by HTTP APIs.

The design deliberately builds on the existing lifecycle-hook mechanism instead of adding service-specific authentication state to the client core.
