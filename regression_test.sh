#!/bin/bash
#// regression test before release
set -x
# all examples
cargo run --release --example 2>&1 | grep -E '^ ' | grep -v basic_consumer | xargs -n1 cargo run --release --all-features --example

# features combination
cargo test 
cargo test -F traces
cargo test -F compliance_assert
cargo test -F tls
cargo test -F urispec
cargo test --all-features



# clippy, warnings not allowed
cargo clippy --all-features -- -Dwarnings

# docs build
cargo doc -p amqprs --all-features --open

# cargo msrv
cargo msrv

# dry-run publish
cargo publish -p amqprs --all-features --dry-run