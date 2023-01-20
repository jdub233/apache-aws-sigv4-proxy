# Apache Proxy with AWS sigv4 signing

This container definition implements a proxy to the S3 REST API with [AWS sigv4 signing](https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html). It is intended to be used with [S3 Object Lambda](https://aws.amazon.com/s3/object-lambda/), but could be used with any S3 REST API.

The signing is done by a bash script that is referenced as an [Apache RewriteMap](https://httpd.apache.org/docs/2.4/rewrite/rewritemap.html) `prg:` program. The script listens for Apache to pass it the
request URI, and returns a signed authorization header for that URI.  It uses a bash `while` loop
to run forever, listening for input from Apache (as specified in the RewriteMap configuration).

It is based on the concept of an [AWS sigv4 signing proxy](https://github.com/awslabs/aws-sigv4-proxy) by [awslabs](https://github.com/awslabs), but implemented with Apache instead of a Go container.

## Running the container

A container image can be built like this:

```bash
docker build  -t apache-prg .
```

The image can be run like this:

```bash
docker run -it -p 80:80 apache-prg
```

This will build and run in a single command:

```bash
docker build  -t apache-prg . && docker run -it -p 80:80 apache-prg
```

## Provision credentials and endpoint through environment variables

The container can be run with environment variables to provision the AWS credentials and the S3 endpoint.  This feature is not yet complete, but here is an example of how it will work:

```bash
docker run -it -p 80:80 \
    -e AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE \
    -e AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
    -e AWS_SECURITY_TOKEN=examplereallylongsecuritytoken \
    -e OBJECT_LAMBDA_HOST=example.s3-object-lambda.us-east-1.amazonaws.com \
    apache-prg
```

## References

https://serverfault.com/questions/592260/add-a-custom-header-to-proxypass-requests
