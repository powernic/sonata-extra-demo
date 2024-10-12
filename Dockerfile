ARG PHP_VERSION=8.2

FROM php:${PHP_VERSION}-fpm-alpine3.17 as admin_php
ENV APCU_VERSION=5.1.21 

RUN set -eux; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
        autoconf \
        automake \
        libtool \
        libzip-dev \
        libxml2-dev \
        m4 \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        postgresql-dev \
        linux-headers \
        icu-dev \
        icu-data-full \
        libpng-dev; \
    apk add --no-cache \
        bash \
        git \
        supervisor; \
    docker-php-ext-install -j$(nproc) \
        opcache \
        intl \
        zip\
        xml \
        soap \
        pdo_pgsql \
        gd \
    ; \
	pecl install apcu-${APCU_VERSION}; \
    pecl install xdebug-3.2.0; \
    pecl install ds; \
    pecl install excimer; \
	pecl clear-cache; \
    docker-php-ext-enable \
        opcache\
        intl\
        zip\
        xml \
        xdebug \
        soap \
        pdo_pgsql \
        apcu \
        ds \
    ;\
    rm -r /tmp/pear; \
    mkdir -p /usr/src/php/ext \
	&& cd /usr/src/php/ext && \
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache --virtual .phpexts-rundeps $runDeps; \
	\
	apk del .build-deps;\
    rm -rf /usr/src; \
    rm -rf /usr/local/include;

COPY --from=ghcr.io/symfony-cli/symfony-cli:5.10.2  /usr/local/bin/symfony /usr/local/bin/symfony

RUN echo "short_open_tag = Off" > /usr/local/etc/php/php.ini


ENV COMPOSER_ALLOW_SUPERUSER=1

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

RUN curl --remote-name --time-cond cacert.pem https://curl.se/ca/cacert.pem \
    && mkdir -p /etc/ssl/certs/ \
    && cp cacert.pem /etc/ssl/certs/ \
    && chown -R www-data:www-data /etc/ssl/certs/cacert.pem

RUN echo "curl.cainfo=\"/etc/ssl/certs/cacert.pem\"" >> /usr/local/etc/php/php.ini \
    && echo "openssl.cafile=\"/etc/ssl/certs/cacert.pem\"" >> /usr/local/etc/php/php.ini \
    && echo "openssl.capath=\"/etc/ssl/certs/cacert.pem\"" >> /usr/local/etc/php/php.ini

RUN echo "apc.enable_cli=1" >> /usr/local/etc/php/php.ini \
	&& echo "apc.enable=1" >> /usr/local/etc/php/php.ini

WORKDIR /var/www/html

USER www-data

COPY --chown=www-data:www-data composer.json .
RUN composer install --prefer-dist --no-dev --no-progress --no-interaction;

ENTRYPOINT ["symfony", "server:start", "--no-tls", "--port=80"]
