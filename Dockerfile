# https://www.howtogeek.com/devops/how-to-use-docker-to-containerise-php-and-apache/
FROM php:8.0.9-apache

COPY ./public-html/ /var/www/html/


COPY custom-apache-site.conf /etc/apache2/sites-available/custom-apache-site.conf

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    a2enmod rewrite && \
    a2dissite 000-default && \
    a2ensite custom-apache-site && \
    service apache2 restart

EXPOSE 80