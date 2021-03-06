FROM ubuntu:20.04 as builder

ENV VERSION 7.9.0

# Install go
RUN apt-get update \
  && apt-get -y install git make build-essential wget
# RUN apk add --no-cache gcc git make musl-dev binutils-gold 

RUN cd /tmp \
  && wget https://golang.org/dl/go1.15.linux-arm64.tar.gz \
  && tar -xvf go1.15.linux-arm64.tar.gz \
  && mv go /usr/local

# Configure Go
ENV GOROOT /usr/local/go
ENV GOPATH /go
ENV PATH $GOPATH/bin:$GOROOT/bin:$PATH
RUN go version
# Get Filebeats src

RUN echo "===> Checking out Filebeat sources..." \
  && go get github.com/elastic/beats; exit 0
WORKDIR /go/src/github.com/elastic/beats/filebeat/
RUN git checkout v$VERSION
ENV GOARCH=arm64
ENV GOOS=linux 
RUN echo "===> Building filebeat..." \
  && go build
RUN mkdir /build
RUN cp filebeat /build/filebeat

########################################################
FROM ubuntu:20.04

ENV VERSION=7.9.0

RUN apt-get update \
  && apt-get -y install wget bash curl jq

RUN \
  cd /tmp \
  && wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${VERSION}-linux-x86_64.tar.gz \
  && tar xzvf filebeat-${VERSION}-linux-x86_64.tar.gz \
  && mv filebeat-${VERSION}-linux-x86_64 /usr/share/filebeat \
  && mkdir /usr/share/filebeat/logs /usr/share/filebeat/data \
  && rm /tmp/*

# Substitute a filebeat binary with the built one
COPY --from=builder /build /usr/share/filebeat
# RUN cp /build/filebeat-arm64 /usr/share/filebeat/filebeat-arm64

ENV PATH $PATH:/usr/share/filebeat

COPY config /usr/share/filebeat

COPY entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint \
  && chmod go-w /usr/share/filebeat/filebeat.yml

WORKDIR /usr/share/filebeat

ENTRYPOINT ["entrypoint"]
CMD ["-h"]
