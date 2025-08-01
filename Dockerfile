## Stage 1: Build stage
#FROM php:8.3-fpm-alpine AS build
#
## Update package index
#RUN apk update
#
## Install build dependencies
#RUN apk add --no-cache --virtual .build-deps \
#    git \
#    unzip \
#    curl \
#    libzip-dev \
#    libpng-dev \
#    libjpeg-turbo-dev \
#    freetype-dev \
#    libwebp-dev \
#    libpq-dev \
#    postgresql-dev \
#    autoconf \
#    g++ \
#    make \
#    pkgconfig \
#    build-base \
#    nodejs \
#    npm \
#    yarn
#
## ---------------------------------------------------------
## Install PHP extensions dengan konfigurasi yang benar
## ---------------------------------------------------------
#RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
#    && docker-php-ext-install -j$(nproc) \
#        pdo_mysql \
#        pdo_pgsql \
#        zip \
#        gd
#
## ---------------------------------------------------------
## Install Composer
## ---------------------------------------------------------
#RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
#
## ---------------------------------------------------------
## Install Node.js tools
## ---------------------------------------------------------
#RUN npm install -g npm
#
## Clean up build dependencies
#RUN apk del .build-deps
#
## Stage 2: Runtime stage
#FROM php:8.2-fpm-alpine
#
## Install runtime dependencies
#RUN apk add --no-cache \
#    libpq \
#    libpng \
#    libjpeg-turbo \
#    libwebp \
#    libzip \
#    nodejs \
#    npm \
#    yarn \
#    bash
#
## Copy Composer
#COPY --from=build /usr/local/bin/composer /usr/local/bin/composer
#
## Copy PHP extensions and config
#COPY --from=build /usr/local/lib/php/extensions /usr/local/lib/php/extensions
#COPY --from=build /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
#
## Set working directory
#WORKDIR /app
#
## Copy application code
#COPY . .
#
## Create storage directories
#RUN mkdir -p /app/storage /app/bootstrap/cache
#
## Set permissions
#RUN chmod -R 775 /app/storage /app/bootstrap/cache && \
#    chown -R www-data:www-data /app/storage /app/bootstrap/cache
#
## Default command
#CMD ["sh", "-c", "composer install --optimize-autoloader --no-dev && \
#    npm install && \
#    npm run build && \
#    php artisan key:generate && \
#    php artisan config:cache && \
#    php artisan route:cache && \
#    php artisan view:cache && \
#    php artisan migrate --force && \
#    php artisan db:seed --force && \
#    php-fpm -F"]

# Stage 1: Build stage
FROM php:8.3-fpm-alpine AS build

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
    postgresql-dev \
    autoconf \
    g++ \
    make \
    pkgconfig \
    build-base \
    nodejs \
    npm \
    yarn

# ---------------------------------------------------------
# Install PHP extensions dengan konfigurasi yang benar
# ---------------------------------------------------------
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
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
FROM php:8.3-fpm-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    libpq \
    libpng \
    libjpeg-turbo \
    libwebp \
    libzip \
    freetype \
    nodejs \
    npm \
    yarn \
    bash

# Install PHP extensions di runtime stage juga
RUN apk add --no-cache --virtual .runtime-deps \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    libpq-dev \
    postgresql-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
        zip \
        gd \
    && apk del .runtime-deps

# Copy Composer
COPY --from=build /usr/local/bin/composer /usr/local/bin/composer

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Create storage directories
RUN mkdir -p /app/storage /app/bootstrap/cache

# Set permissions
RUN chmod -R 775 storage bootstrap/cache && \
    chown -R www-data:www-data storage bootstrap/cache

# Default command
CMD ["sh", "-c", "composer install --optimize-autoloader --no-dev --ignore-platform-reqs && \
    npm install && \
    npm run build && \
    php artisan key:generate && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php-fpm -F"]
