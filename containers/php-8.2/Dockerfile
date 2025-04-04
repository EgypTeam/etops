FROM php:8.2-apache

#RUN sed -i -e 's/deb.debian.org/archive.debian.org/g' \
#           -e 's|security.debian.org|archive.debian.org/|g' \
#           -e '/stretch-updates/d' /etc/apt/sources.list

RUN apt-get update
RUN apt-get install --yes cron g++ gettext libicu-dev openssl 
RUN apt-get install --yes libc-client-dev libkrb5-dev libxml2-dev libfreetype6-dev libgd-dev libmcrypt-dev bzip2 libbz2-dev libtidy-dev libcurl4-openssl-dev libz-dev libmemcached-dev libxslt-dev libjpeg62-turbo-dev apt-transport-https libpng-dev libssl-dev
RUN apt-get install --yes zip unzip telnet 
RUN apt-get install --yes nodejs
RUN apt-get install --yes npm

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/bin/composer
RUN chmod a+x /usr/bin/composer

RUN a2enmod rewrite

RUN docker-php-ext-install mysqli pdo pdo_mysql
RUN docker-php-ext-enable mysqli pdo pdo_mysql

RUN docker-php-ext-configure gd --with-freetype=/usr --with-jpeg=/usr
RUN docker-php-ext-install -j$(nproc) gd

RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
RUN docker-php-ext-enable intl

COPY ./ /var/www/html/


