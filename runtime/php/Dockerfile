ARG PHP_IMAGE=php:7.1-fpm@sha256:9795fa06f3c2732093823fc7b9a0f2c38f613d58c64852da701add54e4bef1b2
ARG COMPOSER_IMAGE=composer:2.2.0@sha256:68bf4d1fa622471a0205e8389fc064699906f1ec85f07c8381d3efbb4a2c02f9
FROM ${COMPOSER_IMAGE} AS composer
FROM ${PHP_IMAGE}

ARG APP_PATH
ARG FRAMEWORK_PATH
ARG FRAMEWORK_PACKAGE
ARG FRAMEWORK_VERSION
ARG PHP_CONFIGURE
ARG SYNTHETIC_DB_PASSWORD
ARG ADMIN_PATH
ARG CUSTOMER_PATH
ARG SELLER_PATH

ENV APP_FRAMEWORK_PACKAGE=${FRAMEWORK_PACKAGE} \
    APP_FRAMEWORK_VERSION=${FRAMEWORK_VERSION} \
    SYNTHETIC_DB_PASSWORD=${SYNTHETIC_DB_PASSWORD} \
    ADMIN_PATH=${ADMIN_PATH} CUSTOMER_PATH=${CUSTOMER_PATH} SELLER_PATH=${SELLER_PATH} \
    COMPOSER_ALLOW_SUPERUSER=1

COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY runtime/php/entrypoint.sh /usr/local/bin/reference-php-entrypoint
RUN chmod 0755 /usr/local/bin/reference-php-entrypoint
COPY ${APP_PATH}/backend/ /var/www/openloyalty/
COPY ${FRAMEWORK_PATH}/ /opt/open-loyalty-framework/

RUN set -eux; \
    sed -i 's|deb.debian.org|archive.debian.org|g; s|security.debian.org|archive.debian.org|g' /etc/apt/sources.list; \
    printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99archive; \
    apt-get update; \
    apt-get install -y --no-install-recommends git unzip libicu-dev libpq-dev libzip-dev libpng-dev libjpeg-dev libxml2-dev zlib1g-dev libcurl4-openssl-dev; \
    docker-php-ext-configure gd ${PHP_CONFIGURE}; \
    docker-php-ext-install -j"$(nproc)" pdo pdo_pgsql pdo_mysql mysqli intl opcache bcmath zip curl gd; \
    rm -rf /var/lib/apt/lists/*

ARG APCU_VERSION=5.1.21
RUN pecl install "apcu-${APCU_VERSION}" \
    && docker-php-ext-enable apcu \
    && printf 'apc.enable_cli=1\n' > /usr/local/etc/php/conf.d/99-apcu-cli.ini

COPY runtime/latest/composer.lock /tmp/profile-latest-composer.lock
COPY runtime/php/configure-profile.sh /usr/local/bin/configure-profile

RUN set -eux; \
    cp /var/www/openloyalty/app/config/parameters.yml.dist /var/www/openloyalty/app/config/parameters.yml; \
    sed -i "s/database_password: openloyalty/database_password: ${SYNTHETIC_DB_PASSWORD}/" /var/www/openloyalty/app/config/parameters.yml; \
    sh /usr/local/bin/configure-profile; \
    chown -R www-data:www-data /var/www/openloyalty /opt/open-loyalty-framework

ARG PHPUNIT_VERSION=7.5.20
WORKDIR /var/www/openloyalty
RUN locked_phpunit=$(php -r '$l=json_decode(file_get_contents("composer.lock"),true); foreach(array_merge($l["packages"] ?? [], $l["packages-dev"] ?? []) as $p) if (($p["name"] ?? "") === "phpunit/phpunit") { echo $p["version"]; exit; }'); \
    if [ "$locked_phpunit" = "$PHPUNIT_VERSION" ]; then \
      echo "Using lockfile PHPUnit ${PHPUNIT_VERSION}"; \
    else \
      composer require --dev --no-scripts --no-interaction --no-progress "phpunit/phpunit:${PHPUNIT_VERSION}"; \
    fi

ENV SYMFONY_ENV=dev
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/reference-php-entrypoint"]
CMD ["php-fpm"]
