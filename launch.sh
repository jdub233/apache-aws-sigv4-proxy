#!/bin/bash

# Write the credentials and host settings from environment variables to a file for the signing script
envsubst < /opt/apache/template.env > /opt/apache/local.env

# Launch apache
apache2-foreground
