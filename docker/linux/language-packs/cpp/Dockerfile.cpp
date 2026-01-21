# docker/linux/language-packs/cpp/Dockerfile.cpp
# C++/GCC toolchain language pack for GitHub Actions runners
# Size: ~250MB (adds to base ~300MB = ~550MB total)

FROM gh-runner:linux-base AS cpp-pack

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install C++ toolchain and build essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    clang \
    clang-format \
    clang-tidy \
    make \
    cmake \
    pkg-config \
    gdb \
    valgrind \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    libgdbm-dev \
    libnss3-dev \
    libpcre3-dev \
    libcurl4-openssl-dev \
    libexpat1-dev \
    libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

# Install CMake 3.x from kitware (if needed for newer version)
# This is optional and can be updated as needed
# RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
#     echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' | tee /etc/apt/sources.list.d/kitware.list && \
#     apt-get update && apt-get install -y cmake && rm -rf /var/lib/apt/lists/*

# Set environment variables for development
ENV CXX=/usr/bin/g++ \
    CC=/usr/bin/gcc \
    CMAKE_C_COMPILER=gcc \
    CMAKE_CXX_COMPILER=g++ \
    BUILD_TYPE=Release

# Verify installations
RUN gcc --version && \
    g++ --version && \
    clang --version && \
    cmake --version && \
    make --version

# Labels
LABEL org.opencontainers.image.description="C++/GCC/Clang toolchain for GitHub Actions runners" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.gcc.version="11.x" \
      org.opencontainers.image.clang.version="14.x" \
      org.opencontainers.image.cmake.version="3.x"

USER runner
WORKDIR /actions-runner
