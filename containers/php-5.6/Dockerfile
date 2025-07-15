FROM php:5.6-apache

# Atualiza os repositórios antigos do Debian
RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
           -e 's|security.debian.org|archive.debian.org/|g' \
           -e '/stretch-updates/d' /etc/apt/sources.list

# Instala dependências do sistema e do PHP
RUN apt-get update && \
    apt-get install --yes --force-yes \
    cron g++ gettext libicu-dev openssl libc-client-dev libkrb5-dev \
    libxml2-dev libfreetype6-dev libgd-dev libmcrypt-dev bzip2 libbz2-dev \
    libtidy-dev libcurl4-openssl-dev libz-dev libmemcached-dev libxslt-dev \
    libjpeg62-turbo-dev apt-transport-https libpng-dev libssl-dev \
    zip unzip telnet openssh-client \
    imagemagick libmagickwand-dev && \
    pecl install imagick && \
    echo "extension=imagick.so" > /usr/local/etc/php/conf.d/imagick.ini

# Ativa módulos do Apache
RUN a2enmod rewrite

# Instala extensões do PHP
RUN docker-php-ext-install mysql
RUN docker-php-ext-enable mysql

RUN docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr
RUN docker-php-ext-install -j$(nproc) gd iconv mcrypt zip bcmath

# Copia o projeto para o container
COPY ./ /var/www/html/
