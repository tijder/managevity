#!/bin/sh
# Writes the pieces of config that envsubst cannot produce: a shared proxy fragment and,
# only when NEXTCLOUD_UPSTREAM is set, the CalDAV proxy. That one lives on the same path as
# on Nextcloud itself, so the hrefs in the DAV responses are also correct through the proxy.
set -eu

conf=/etc/nginx/conf.d
ca="${UPSTREAM_CA_FILE:-/etc/ssl/certs/ca-certificates.crt}"

cat > "$conf/proxy-common.inc" <<INC
proxy_http_version 1.1;
proxy_ssl_server_name on;
proxy_ssl_verify on;
proxy_ssl_verify_depth 4;
proxy_ssl_trusted_certificate $ca;
proxy_set_header Host \$proxy_host;
proxy_set_header Connection "";
proxy_set_header Cookie "";
proxy_hide_header Set-Cookie;
proxy_connect_timeout 15s;
proxy_read_timeout 60s;
proxy_redirect off;
INC

: > "$conf/dav.inc"
upstream="${NEXTCLOUD_UPSTREAM:-}"
[ -n "$upstream" ] || exit 0

# Only scheme://host[:port]; anything else would end up in the nginx config.
if ! printf '%s' "$upstream" | grep -Eq '^https?://[A-Za-z0-9.-]+(:[0-9]+)?$|^https?://\[[0-9A-Fa-f:]+\](:[0-9]+)?$'; then
    echo "18-dav-proxy.sh: NEXTCLOUD_UPSTREAM must be scheme://host[:port], without a path" >&2
    exit 1
fi

cat > "$conf/dav.inc" <<INC
location /remote.php/dav/ {
    set \$nextcloud $upstream;
    proxy_pass \$nextcloud;
    include $conf/proxy-common.inc;
    # CalDAV: PROPFIND/REPORT/PUT/DELETE and their headers pass through unchanged.
    proxy_pass_request_headers on;
    proxy_request_buffering off;
    # Otherwise the browser shows its own login dialog on a wrong password.
    proxy_hide_header WWW-Authenticate;
}
location = /.well-known/caldav {
    return 301 /remote.php/dav/;
}
INC
echo "18-dav-proxy.sh: CalDAV proxy to $upstream enabled"
