ARG ALPINE_VERSION=3.12.1
FROM alpine:${ALPINE_VERSION} AS builder
MAINTAINER Xavier Garnier 'xavier.garnier@irisa.fr'

# Environment variables
ENV VIRTUOSO_GIT_URL https://github.com/openlink/virtuoso-opensource.git
ENV VIRTUOSO_DIR /virtuoso-opensource
#ENV VIRTUOSO_GIT_VERSION v7.2.5.1  include the v
ENV VIRTUOSO_GIT_VERSION develop/7

# Install prerequisites
RUN apk add --update git automake autoconf automake libtool bison flex gawk gperf openssl g++ openssl-dev make patch file

COPY patch.diff /patch.diff

# Download, Patch, compile and install
RUN git clone -b ${VIRTUOSO_GIT_VERSION} --single-branch --depth=1 ${VIRTUOSO_GIT_URL} ${VIRTUOSO_DIR} && \
    cd ${VIRTUOSO_DIR} && \
    patch ${VIRTUOSO_DIR}/libsrc/Wi/sparql_io.sql < /patch.diff && \
    ./autogen.sh && \
    CFLAGS="-O2 -m64" && export CFLAGS && \
    ./configure --disable-bpel-vad --enable-conductor-vad --enable-fct-vad --disable-dbpedia-vad --disable-demo-vad --disable-isparql-vad --enable-ods-vad --disable-sparqldemo-vad --disable-syncml-vad --disable-tutorial-vad --program-transform-name="s/isql/isql-v/" && \
    make -j $(grep -c '^processor' /proc/cpuinfo) && \
    make -j $(grep -c '^processor' /proc/cpuinfo) install


# Final image
FROM alpine:${ALPINE_VERSION}
ENV PATH /usr/local/virtuoso-opensource/bin/:$PATH
RUN apk add --no-cache openssl py-pip && \
    pip install crudini && \
    mkdir -p /usr/local/virtuoso-opensource/var/lib/virtuoso/db && \
    ln -s /usr/local/virtuoso-opensource/var/lib/virtuoso/db /data

COPY --from=builder /usr/local/virtuoso-opensource /usr/local/virtuoso-opensource
COPY virtuoso.ini dump_nquads_procedure.sql clean-logs.sh virtuoso.sh /virtuoso/

WORKDIR /data
EXPOSE 8890 1111

CMD sh /virtuoso/virtuoso.sh
