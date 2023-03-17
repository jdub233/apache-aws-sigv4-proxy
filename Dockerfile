# https://www.howtogeek.com/devops/how-to-use-docker-to-containerise-php-and-apache/
FROM php:8.0.9-apache

# For signature crypto
RUN apt-get update
RUN apt-get install -y bsdmainutils
RUN apt-get install gettext-base

WORKDIR /opt
COPY ./launch.sh ./

COPY ./public-html/ /var/www/html/

RUN mkdir /opt/apache
COPY ./header-script/sigv4-loop.sh /opt/apache/sigv4-loop.sh
COPY ./header-script/template.env /opt/apache/template.env

COPY custom-apache-site.conf /etc/apache2/sites-available/custom-apache-site.conf
COPY ports.conf /etc/apache2/ports.conf

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    a2enmod rewrite && \
    a2enmod headers && \
    a2enmod ssl && \
    a2enmod proxy && \
    a2enmod proxy_http && \
    a2dissite 000-default && \
    a2ensite custom-apache-site && \
    service apache2 restart

RUN rm -rf /run/apache2 && mkdir /run/apache2 && \
    chmod -R a+rwx /run/apache2 && \
    chmod -R a+rwx /opt/apache && \
    chmod -R a+rwx /var/www/html && \
    chmod -R a+rwx /opt/launch.sh

USER 1001

# Pull the environment variables from the template into a file for the signing script to use, and launch apache
CMD [ "./launch.sh" ]

EXPOSE 8080
