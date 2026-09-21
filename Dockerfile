# Serves the web build and proxies the API, so everything is same-origin: the Sportivity
# API sends no CORS headers, so a browser cannot reach it directly.
#
# The image does not build Flutter itself: build/web must already exist (tool/build-image.sh
# locally, the web-build artifact in CI). That makes multi-arch free.
FROM nginxinc/nginx-unprivileged:1.31.6-alpine

LABEL org.opencontainers.image.title="Managevity" \
      org.opencontainers.image.description="Managevity for Sportivity — unofficial client, not affiliated with b.o.s.s." \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

# Fixed upstreams from the environment; the proxy never forwards to a host taken from the request.
ENV SPORTIVITY_UPSTREAM=https://www.sportivity.com \
    NEXTCLOUD_UPSTREAM= \
    UPSTREAM_CA_FILE=/etc/ssl/certs/ca-certificates.crt \
    # Have the entrypoint take the resolvers from /etc/resolv.conf (IPv6 too, in brackets).
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    # Substitute only these variables, so $uri and friends survive in the template.
    NGINX_ENVSUBST_FILTER='^(SPORTIVITY_UPSTREAM|UPSTREAM_CA_FILE|NGINX_LOCAL_RESOLVERS)$'

COPY docker/default.conf.template /etc/nginx/templates/default.conf.template
COPY --chmod=0755 docker/18-dav-proxy.sh /docker-entrypoint.d/18-dav-proxy.sh
COPY build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
