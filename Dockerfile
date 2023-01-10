# Instruction for Dockerfile to create a new image on top of the base image (httpd)
FROM httpd:2.4

COPY ./public-html/ /usr/local/apache2/htdocs/
EXPOSE 80