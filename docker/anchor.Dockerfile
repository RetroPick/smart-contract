FROM backpackapp/build:v0.31.0
WORKDIR /workspace

COPY Anchor.toml Cargo.toml Cargo.lock ./
COPY programs programs

RUN anchor build
