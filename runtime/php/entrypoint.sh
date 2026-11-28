#!/bin/sh
set -eu

jwt_dir=/var/www/openloyalty/app/var/jwt
private_key="$jwt_dir/private.pem"
public_key="$jwt_dir/public.pem"

if [ ! -s "$private_key" ] || [ ! -s "$public_key" ]; then
    mkdir -p "$jwt_dir"
    openssl genrsa -out "$private_key" 4096
    openssl rsa -pubout -in "$private_key" -out "$public_key"
    chmod 0600 "$private_key"
    chmod 0644 "$public_key"
    chown www-data:www-data "$private_key" "$public_key"
fi

# The synthetic setup fixtures store references to these default images in
# PostgreSQL. Recreate the files if a disposable PHP container is replaced.
default_logo=$(find /var/www/openloyalty/vendor -path '*/SettingsBundle/Resources/images/logo/logo.png' -type f -print -quit)
if [ -n "$default_logo" ]; then
    upload_logo_dir=/var/www/openloyalty/app/uploads/logo
    mkdir -p "$upload_logo_dir"
    for image_name in logo small-logo hero-image admin-cockpit-logo client-cockpit-logo-big client-cockpit-logo-small client-cockpit-hero-image; do
        if [ ! -s "$upload_logo_dir/$image_name.png" ]; then
            cp "$default_logo" "$upload_logo_dir/$image_name.png"
            chown www-data:www-data "$upload_logo_dir/$image_name.png"
        fi
    done
fi

exec "$@"
