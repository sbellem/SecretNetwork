FROM baiduxlab/sgx-rust:2004-1.1.3

### Install rocksdb

RUN apt-get update &&  \
    apt-get install -y \
    # apt-get install -y --no-install-recommends \
#    libgflags-dev \
#    libsnappy-dev \
    zlib1g-dev \
    cmake
#    libbz2-dev \
#    liblz4-dev \
#    libzstd-dev

RUN git clone https://github.com/facebook/rocksdb.git

WORKDIR rocksdb

ARG BUILD_VERSION="v6.24.2"

RUN git checkout ${BUILD_VERSION}

RUN mkdir -p build && cd build && cmake \
		-DWITH_SNAPPY=0 \
		-DWITH_LZ4=0 \
		-DWITH_ZLIB=0 \
		-DWITH_ZSTD=0 \
		-DWITH_GFLAGS=0 \
		-DROCKSDB_BUILD_SHARED=0 \
		-DWITH_TOOLS=0 \
		-DWITH_BENCHMARK_TOOLS=0 \
		-DWITH_CORE_TOOLS=0 \
		-DWITH_JEMALLOC=0 \
		-DCMAKE_BUILD_TYPE=Release \
		.. && make -j 24

RUN make install-static INSTALL_PATH=/usr

CMD ['/bin/bash']