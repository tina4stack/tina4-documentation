# Feature 040: Frond fragment caching

## Identity and status

- Matrix identity: 40 - `{% cache %}` fragment caching
- Current state: reopened / queued for a standalone 3.14 audit
- Historical evidence was mixed into the Feature 43 cache-backend audit
- Dependencies: Feature 31 runtime and Feature 43 cache providers

Feature 40 owns fragment key construction, TTL semantics, rendered-fragment
storage and invalidation. It does not own compiled-template caching (Feature 39)
or the provider's generic KV contract (Feature 43).

The historical audit measured one concrete divergence: a missing TTL meant 60
seconds in Python/Ruby/Node and forever in PHP, while explicit zero meant no
cache in three ports and forever in PHP. PHP was aligned to the three-port rule.
It also recorded that `Frond.clear_cache()` cleared no fragment cache in any
port. A shared fixture and complete invalidation decision are still required.
