FROM php:7.4-apache

RUN apt-get update && \
    apt-get install --yes --force-yes \
    cron g++ gettext libicu-dev openssl libc-client-dev libkrb5-dev \
    libxml2-dev libfreetype6-dev libgd-dev libmcrypt-dev bzip2 libbz2-dev \
    libtidy-dev libcurl4-openssl-dev libz-dev libmemcached-dev libxslt-dev \
    libjpeg62-turbo-dev apt-transport-https libpng-dev libssl-dev zip unzip \
    telnet openssh-client \
    imagemagick libmagickwand-dev && \
    pecl install imagick && \
    docker-php-ext-enable imagick

# Enable Apache modules
RUN a2enmod rewrite
RUN a2enmod headers

# PHP extensions
RUN docker-php-ext-install mysqli pdo pdo_mysql xml json phar
RUN docker-php-ext-enable mysqli pdo pdo_mysql xml json phar

# GD extension
RUN docker-php-ext-configure gd --with-freetype=/usr --with-jpeg=/usr
RUN docker-php-ext-install -j$(nproc) gd

COPY ./ /var/www/html/
