# Serves the web build and proxies the API, so everything is same-origin: the Sportivity
# API sends no CORS headers, so a browser cannot reach it directly.
#
# The image does not build Flutter itself: build/web must already exist (tool/build-image.sh
# locally, the web-build artifact in CI). That makes multi-arch free.
FROM docker.io/nginx/nginx-unprivileged:1.31.9-alpine

# The base image carries the Alpine packages of the build its tag points to, and
# nginx does not rebuild it when Alpine ships a security fix. CVE-2026-111497
# (brotli decoder, fixed in brotli 1.2.1-r0) sat in 1.31.6 and 1.31.7 alike while
# the fix was already in the Alpine 3.24 repository; upgrading here closes that
# gap on every build instead of waiting for upstream.
USER root
RUN apk -U upgrade --no-cache
USER nginx

LABEL org.opencontainers.image.title="Managevity" \
      org.opencontainers.image.description="Managevity for Sportivity — unofficial client, not affiliated with b.o.s.s." \
      org.opencontainers.image.licenses="GPL-3.0-or-later"

# Fixed upstreams from the environment; the proxy never forwards to a host taken from the request.
ENV SPORTIVITY_UPSTREAM=https://www.sportivity.com \
    NEXTCLOUD_UPSTREAM= \
    UPSTREAM_CA_FILE=/etc/ssl/certs/ca-certificates.crt \
    # Requests to /api/ per client address, and how many may come at once.
    API_RATE=10r/s \
    API_BURST=40 \
    # Content-Security-Policy-Report-Only to try a policy without enforcing it.
    CSP_HEADER=Content-Security-Policy \
    # Have the entrypoint take the resolvers from /etc/resolv.conf (IPv6 too, in brackets).
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    # Substitute only these variables, so $uri and friends survive in the template.
    NGINX_ENVSUBST_FILTER='^(SPORTIVITY_UPSTREAM|UPSTREAM_CA_FILE|NGINX_LOCAL_RESOLVERS|API_RATE|API_BURST|CSP_HEADER)$'

COPY docker/default.conf.template /etc/nginx/templates/default.conf.template
COPY --chmod=0755 docker/18-dav-proxy.sh /docker-entrypoint.d/18-dav-proxy.sh
COPY build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
