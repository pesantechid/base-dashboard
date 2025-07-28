# Stage 1: Build stage
FROM php:8.2-fpm-alpine AS build

# Update package index
RUN apk update

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

# ---------------------------------------------------------
# FIX: Symlink untuk header yang tidak ditemukan
# ---------------------------------------------------------
# PHP 8.2+ butuh ini karena lokasi header berubah
RUN ln -s /usr/include/freetype2 /usr/include/freetype
RUN ln -s /usr/lib/libjpeg.so /usr/lib/libjpeg.so.8  # Fix libjpeg

# ---------------------------------------------------------
# Konfigurasi GD sebelum install
# ---------------------------------------------------------
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# ---------------------------------------------------------
# Install PHP extensions
# ---------------------------------------------------------
RUN docker-php-ext-install \
    pdo_mysql \
    pdo_pgsql \
    zip \
    gd

# ---------------------------------------------------------
# Install Composer
# ---------------------------------------------------------
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# ---------------------------------------------------------
# Install Node.js tools
# ---------------------------------------------------------
RUN npm install -g npm

# Clean up build dependencies
RUN apk del .build-deps

# Stage 2: Runtime stage
FROM php:8.2-fpm-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    libpq \
    libpng \
    libjpeg-turbo \
    libwebp \
    libzip \
    nodejs \
    npm \
    yarn \
    bash

# Copy Composer
COPY --from=build /usr/local/bin/composer /usr/local/bin/composer

# Copy PHP extensions and config
COPY --from=build /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=build /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Create storage directories
RUN mkdir -p /app/storage /app/bootstrap/cache

# Set permissions
RUN chmod -R 775 /app/storage /app/bootstrap/cache && \
    chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Default command
CMD ["sh", "-c", "composer install --optimize-autoloader --no-dev && \
    npm install && \
    npm run build && \
    php artisan key:generate && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan migrate --force && \
    php artisan db:seed --force && \
    php-fpm -F"]
