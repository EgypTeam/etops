FROM php:8.1-apache

#RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
#           -e 's|security.debian.org|archive.debian.org/|g' \
#           -e '/stretch-updates/d' /etc/apt/sources.list

RUN apt-get update
RUN apt-get install --yes --force-yes cron g++ gettext libicu-dev openssl libc-client-dev libkrb5-dev  libxml2-dev libfreetype6-dev libgd-dev libmcrypt-dev bzip2 libbz2-dev libtidy-dev libcurl4-openssl-dev libz-dev libmemcached-dev libxslt-dev libjpeg62-turbo-dev apt-transport-https libpng-dev libssl-dev zip unzip telnet

RUN a2enmod rewrite

RUN docker-php-ext-install mysqli pdo pdo_mysql
RUN docker-php-ext-enable mysqli pdo pdo_mysql

RUN docker-php-ext-configure gd --with-freetype=/usr --with-jpeg=/usr
RUN docker-php-ext-install -j$(nproc) gd

RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
RUN docker-php-ext-enable intl

COPY ./ /var/www/html/


