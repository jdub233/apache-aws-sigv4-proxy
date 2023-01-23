#!/bin/bash

# This script is used to write the environment variables to a file
envsubst < /opt/apache/template.env > /opt/apache/local.env

apache2-foreground
