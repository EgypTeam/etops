FROM php:8.2-apache

# Uncomment if using old Debian mirrors
# RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
#            -e 's|security.debian.org|archive.debian.org/|g' \
#            -e '/stretch-updates/d' /etc/apt/sources.list

RUN apt-get update && \
    apt-get install --yes \
    cron g++ gettext libicu-dev openssl openssh-client \
    libc-client-dev libkrb5-dev libxml2-dev libfreetype6-dev libgd-dev \
    bzip2 libbz2-dev libtidy-dev libcurl4-openssl-dev libz-dev \
    libmemcached-dev libxslt-dev libjpeg62-turbo-dev apt-transport-https \
    libpng-dev libssl-dev zip unzip telnet nodejs npm \
    imagemagick libmagickwand-dev && \
    pecl install imagick && \
    docker-php-ext-enable imagick

# Composer installation (safe and current method)
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# Enable Apache rewrite module
RUN a2enmod rewrite

# Install PHP extensions
RUN docker-php-ext-install mysqli pdo pdo_mysql
RUN docker-php-ext-enable mysqli pdo pdo_mysql

RUN docker-php-ext-configure gd --with-freetype=/usr --with-jpeg=/usr
RUN docker-php-ext-install -j$(nproc) gd

RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
RUN docker-php-ext-enable intl

# Copy source
COPY ./ /var/www/html/
