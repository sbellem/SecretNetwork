FROM node:19

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

COPY --from=rust:1.64 /usr/local/rustup /usr/local/rustup
COPY --from=rust:1.64 /usr/local/cargo /usr/local/cargo

WORKDIR integration-tests
COPY integration-tests .

