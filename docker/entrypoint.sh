#!/usr/bin/env sh
set -e

if [ "${APP_ENV}" = "production" ]; then
    php artisan key:generate --force || true

    if [ "${RUN_OPTIMIZE}" = "true" ]; then
        php artisan config:cache || true
        php artisan route:cache || true
        php artisan view:cache || true
    fi

    if [ "${RUN_MIGRATIONS}" = "true" ]; then
        php artisan migrate --force || true
    fi
fi

exec php-fpm

