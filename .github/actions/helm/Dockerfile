FROM alpine/helm:latest

ENV HELM_PLUGINS=/opt/helm/plugins

RUN  apk add --no-cache bash curl jq \
  && apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing kubectl \
  && mkdir -p /opt/helm/plugins \
  && helm plugin install https://github.com/hypnoglow/helm-s3.git

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

CMD ["helm", "--help"]
