# Apache Proxy with AWS sigv4 signing

Implements a proxy to the S3 REST API with AWS sigv4 signing. It implements the signing algorithm described here: https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html

The signing is done by a bash script that is referenced as an [Apache RewriteMap](https://httpd.apache.org/docs/2.4/rewrite/rewritemap.html). The script is based on the one found here: https://gist.github.com/slawekzachcial/fe23184124763dfb82f233b5dde2394b

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

## References

https://serverfault.com/questions/592260/add-a-custom-header-to-proxypass-requests
