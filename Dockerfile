# syntax=docker/dockerfile:1

# bump: libass /LIBASS_VERSION=([\d.]+)/ https://github.com/libass/libass.git|*
# bump: libass after ./hashupdate Dockerfile LIBASS $LATEST
# bump: libass link "Release notes" https://github.com/libass/libass/releases/tag/$LATEST
ARG LIBASS_VERSION=0.16.0
ARG LIBASS_URL="https://github.com/libass/libass/releases/download/$LIBASS_VERSION/libass-$LIBASS_VERSION.tar.gz"
ARG LIBASS_SHA256=fea8019b1887cab9ab00c1e58614b4ec2b1cee339b3f7e446f5fab01b032d430

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG LIBASS_URL
ARG LIBASS_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libass.tar.gz "$LIBASS_URL" && \
  echo "$LIBASS_SHA256  libass.tar.gz" | sha256sum --status -c - && \
  mkdir libass && \
  tar xf libass.tar.gz -C libass --strip-components=1 && \
  rm libass.tar.gz && \
  apk del download

FROM base AS build
COPY --from=download /tmp/libass/ /tmp/libass/
WORKDIR /tmp/libass
RUN \
  apk add --no-cache --virtual build \
    build-base pkgconf \
    freetype freetype-dev freetype-static \
    fribidi-dev fribidi-static \
    harfbuzz-dev harfbuzz-static \
    fontconfig-dev fontconfig-static && \
  ./configure --disable-shared --enable-static && \
  make -j$(nproc) && make install && \
  # Sanity tests
  pkg-config --exists --modversion --path libass && \
  ar -t /usr/local/lib/libass.a && \
  readelf -h /usr/local/lib/libass.a && \
  # Cleanup
  apk del build

FROM scratch
ARG LIBASS_VERSION
COPY --from=build /usr/local/lib/pkgconfig/libass.pc /usr/local/lib/pkgconfig/libass.pc
COPY --from=build /usr/local/lib/libass.a /usr/local/lib/libass.a
COPY --from=build /usr/local/include/ass/ /usr/local/include/ass/
