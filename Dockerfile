# -------------------------------
# Stage 1: Build Frontend Assets
# -------------------------------
FROM node:20-alpine AS frontend

WORKDIR /app

# Copy only necessary files for npm install cache
COPY package*.json ./
RUN npm install

# Copy all frontend source code
COPY . .

# Build frontend assets (e.g. Vite, Laravel Mix)
RUN npm run build


# -------------------------------
# Stage 2: Laravel PHP App
# -------------------------------
FROM php:8.3-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl zip libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libonig-dev \
    libpq-dev libxml2-dev libssl-dev \
    && docker-php-ext-install pdo pdo_pgsql zip mbstring tokenizer xml bcmath \
    && docker-php-ext-configure gd --with-jpeg --with-freetype \
    && docker-php-ext-install gd

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy Laravel app source code
COPY . .

# Copy frontend build output
COPY --from=frontend /app/public/build /var/www/public/build

# Install PHP dependencies including dev (faker, artisan, etc.)
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Set proper permissions
RUN chown -R www-data:www-data /var/www \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Optional: Set Laravel permissions via entrypoint (if using)
# COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port 9000 (php-fpm default)
EXPOSE 9000

# Default command
CMD ["php-fpm"]
