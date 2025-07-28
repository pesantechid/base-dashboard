# Stage 1: Build stage for PHP dependencies and Node.js assets
FROM php:8.3-fpm-alpine AS build

# Install build dependencies for PHP extensions and Node.js
RUN apk add --no-cache --virtual .build-deps \
    git \
    unzip \
    curl \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    freetype-dev \
    libwebp-dev \
    libpq-dev \
    build-base \
    nodejs \
    npm \
    yarn && \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install \
        pdo_mysql \
        pdo_pgsql \
        zip \
        gd

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set working directory for the build
WORKDIR /app

# Install Node.js globally (already in image), but ensure npm is updated
RUN npm install -g npm

# Clean up build dependencies to reduce image size
RUN apk del .build-deps

# Stage 2: Runtime stage
FROM php:8.3-fpm-alpine

# Install only runtime dependencies
RUN apk add --no-cache \
    libpq \
    libpng \
    libjpeg \
    libwebp \
    libzip \
    nodejs \
    npm \
    yarn \
    bash

# Copy Composer from the build stage
COPY --from=build /usr/local/bin/composer /usr/local/bin/composer

# Copy PHP extensions and configuration from the build stage
COPY --from=build /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=build /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d

# Set working directory
WORKDIR /app

# Copy application files (codebase)
COPY . .

# Ensure Laravel directories exist
RUN mkdir -p /app/storage /app/bootstrap/cache

# Set appropriate permissions
RUN chmod -R 775 /app/storage /app/bootstrap/cache && \
    chown -R www-data:www-data /app/storage /app/bootstrap/cache

# Optional: Create symbolic link for storage (if needed)
# RUN php artisan storage:link

# Install PHP dependencies and build frontend assets
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
