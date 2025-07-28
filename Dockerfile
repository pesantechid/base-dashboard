# Stage 1: Build stage
FROM php:8.3-fpm-alpine AS build

# Update package index dan install dependencies
RUN apk update && apk upgrade

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    git \
    unzip \
    curl \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    libpq-dev \
    build-base \
    nodejs \
    npm \
    yarn

# Fix: Alpine 3.19+ membutuhkan symlink untuk freetype
RUN ln -s /usr/include/freetype2 /usr/include/freetype

# Konfigurasi ekstensi GD (untuk PHP 8.3)
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# Install PHP extensions
RUN docker-php-ext-install \
    pdo_mysql \
    pdo_pgsql \
    zip \
    gd

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Stage 2: Runtime
FROM php:8.3-fpm-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    libzip \
    libpng \
    libjpeg-turbo \
    libwebp \
    libpq \
    nodejs \
    npm \
    yarn \
    bash

# Copy Composer
COPY --from=build /usr/local/bin/composer /usr/local/bin/composer

# Copy extensions
COPY --from=build /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=build /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Set working dir
WORKDIR /app

# Copy app
COPY . .

# Create dirs
RUN mkdir -p /app/storage /app/bootstrap/cache

# Permissions
RUN chmod -R 775 /app/storage /app/bootstrap/cache && \
    chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Final command
CMD ["sh", "-c", "composer install --optimize-autoloader --no-dev && \
    npm install && \
    npm run build && \
    php artisan key:generate && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan migrate --force && \
    php-fpm -F"]
