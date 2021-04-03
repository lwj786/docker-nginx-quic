FROM alpine as builder

WORKDIR /build

RUN set -ex; \
    apk add --no-cache \
        git \
        mercurial \
    \
    && git clone https://boringssl.googlesource.com/boringssl \
    && hg clone -b quic https://hg.nginx.org/nginx-quic

RUN set -ex; \
    apk add --no-cache \
        linux-headers \
        cmake \
        make \
        g++ \
        go \
        perl

RUN set -ex; \
    mkdir boringssl/build && cd boringssl/build \
    && cmake .. && make

RUN set -ex; \
    apk add --no-cache \
         pcre-dev \
         zlib-dev

RUN set -ex; \
    cd nginx-quic && ./auto/configure \
        --with-http_v3_module \
        --with-http_quic_module \
        --with-stream_quic_module \
        --with-cc-opt="-I../boringssl/include"   \
        --with-ld-opt="-L../boringssl/build/ssl  \
            -L../boringssl/build/crypto" \
    && make \
    && mkdir -p /tmp/nginx-quic && make DESTDIR=/tmp/nginx-quic install \
    && tar cf /tmp/nginx-quic.tar -C /tmp/nginx-quic `ls /tmp/nginx-quic`

FROM alpine

COPY --from=builder /tmp/nginx-quic.tar /tmp

RUN set -ex; \
    tar xf /tmp/nginx-quic.tar -C / && rm /tmp/nginx-quic.tar

RUN set -ex; \
    apk add --no-cache \
        pcre

ENTRYPOINT [ "/usr/local/nginx/sbin/nginx" ]
CMD [ "-g", "daemon off;" ]
