# docker/linux/language-packs/go/Dockerfile.go
# Go 1.22 language pack for GitHub Actions runners
# Size: ~100MB (adds to base ~300MB = ~400MB total)

FROM gh-runner:linux-base AS go-pack

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Go 1.22 from official Go release
# This ensures we get the exact version needed
ARG GO_VERSION=1.22.7

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download and install Go
RUN wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz

# Update PATH to include Go binaries
ENV PATH="/usr/local/go/bin:${PATH}"

# Create Go workspace directory
RUN mkdir -p /go && chown -R runner:runner /go

# Environment variables for Go development
ENV GOROOT=/usr/local/go \
    GOPATH=/go \
    GO111MODULE=on

# Verify Go installation
RUN go version && \
    go env GOPATH GOROOT

# Labels
LABEL org.opencontainers.image.description="Go 1.22 toolchain for GitHub Actions runners" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.go.version="${GO_VERSION}" \
      org.opencontainers.image.size="~100MB"

USER runner
WORKDIR /actions-runner
