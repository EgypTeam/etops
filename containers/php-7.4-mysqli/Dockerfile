FROM php:7.4-apache

#RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
#           -e 's|security.debian.org|archive.debian.org/|g' \
#           -e '/stretch-updates/d' /etc/apt/sources.list

RUN apt-get update && \
    apt-get install --yes --force-yes \
    cron g++ gettext libicu-dev openssl libc-client-dev libkrb5-dev \
    libxml2-dev libfreetype6-dev libgd-dev libmcrypt-dev bzip2 libbz2-dev \
    libtidy-dev libcurl4-openssl-dev libz-dev libmemcached-dev libxslt-dev \
    libjpeg62-turbo-dev apt-transport-https libpng-dev libssl-dev \
    zip unzip telnet \
    imagemagick libmagickwand-dev && \
    pecl install imagick && \
    docker-php-ext-enable imagick

# Habilita módulo do Apache
RUN a2enmod rewrite

# Instala e habilita extensões PHP
RUN docker-php-ext-install mysqli pdo pdo_mysql xml json phar
RUN docker-php-ext-enable mysqli pdo pdo_mysql xml json phar

# Instala GD com suporte a freetype e jpeg
RUN docker-php-ext-configure gd --with-freetype=/usr --with-jpeg=/usr
RUN docker-php-ext-install -j$(nproc) gd

# Copia o código-fonte da aplicação
COPY ./ /var/www/html/
