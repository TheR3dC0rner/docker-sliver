  
FROM golang:1.16.3 AS build

ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG COMMIT="local"
ARG VERSION="v1.4.12"

#
# IMPORTANT: This Dockerfile is used for testing, I do not recommend deploying
#            Sliver using this container configuration! However, if you do want
#            a Docker deployment this is probably a good place to start.
#

ENV PROTOC_VER 3.15.8
ENV PROTOC_GEN_GO_VER v1.26.0
ENV GRPC_GO v1.1.0

# Base packages
RUN apt-get update --fix-missing && apt-get -y install \
  git build-essential zlib1g zlib1g-dev \
  libxml2 libxml2-dev libxslt-dev locate curl \
  libreadline6-dev libcurl4-openssl-dev git-core \
  libssl-dev libyaml-dev openssl autoconf libtool \
  ncurses-dev bison curl wget xsel postgresql \
  postgresql-contrib postgresql-client libpq-dev \
  libapr1 libaprutil1 libsvn1 \
  libpcap-dev libsqlite3-dev libgmp3-dev \
  zip unzip mingw-w64 binutils-mingw-w64 g++-mingw-w64 \
  nasm gcc-multilib

#
# > User
#
RUN groupadd -g 999 sliver && useradd -r -u 999 -g sliver sliver
RUN mkdir -p /home/sliver/ && chown -R sliver:sliver /home/sliver

#
# > Metasploit
#
#RUN curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall \
#  && chmod 755 msfinstall \
#  && ./msfinstall
#RUN mkdir -p ~/.msf4/ && touch ~/.msf4/initial_setup_complete \
#    &&  su -l sliver -c 'mkdir -p ~/.msf4/ && touch ~/.msf4/initial_setup_complete'

#
# > Sliver
#

# protoc
WORKDIR /tmp
RUN wget -O protoc-${PROTOC_VER}-linux-x86_64.zip https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VER}/protoc-${PROTOC_VER}-linux-x86_64.zip \
    && unzip protoc-${PROTOC_VER}-linux-x86_64.zip \
    && cp -vv ./bin/protoc /usr/local/bin

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VER} \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@${GRPC_GO}

# assets
RUN git clone https://github.com/bishopfox/sliver /go/src/github.com/bishopfox/sliver
WORKDIR /go/src/github.com/bishopfox/sliver
RUN ./go-assets.sh
RUN go mod vendor && make linux && cp -vv sliver-server /opt/sliver-server

#RUN ls -lah \
#    && /opt/sliver-server unpack --force \
#    && /go/src/github.com/bishopfox/sliver/go-tests.sh
RUN make clean 
    # && rm -rf /go/src/* \
    # && rm -rf /home/sliver/.sliver

FROM alpine:latest AS runtime
RUN addgroup -S sliver && adduser -S sliver -G sliver &&\
mkdir -p /home/sliver/ && chown -R sliver:sliver /home/sliver &&\
apk add --no-cache mingw-w64-gcc mingw-w64-binutils 

COPY docker-entrypoint.sh /home/sliver/docker-entrypoint.sh
RUN chown sliver:sliver /home/sliver/docker-entrypoint.sh && chmod +x /home/sliver/docker-entrypoint.sh

# apt-get update && apt-get --no-install-recommends -y install \  
#  mingw-w64 binutils-mingw-w64 g++-mingw-w64 \
#  && apt-get clean 

COPY --from=build /opt/sliver-server /opt/sliver-server
USER sliver
WORKDIR /home/sliver/
ENTRYPOINT ./docker-entrypoint.sh

