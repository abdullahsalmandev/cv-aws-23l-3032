# Host Your CV on AWS - 23L-3032

Region: TODO

## Architecture

```
                     +--------------------------+
                     |   S3 bucket (PRIVATE)    |
                     |   cv-23l-3032/site/      |
                     +--------------------------+
                        ^                    ^
        sync (EC2 role) |                    | GetObject (Lambda role)
                        |                    |
 Visitor --HTTP--> EC2 httpd            Lambda cv-func-23l-3032
 (path 1)          cv-ec2-23l-3032            ^
                                              |
 Visitor --HTTPS--> Lambda Function URL ------+
 (path 2)
```

## How a request reaches the CV

EC2 path: TODO (two sentences total for both paths)

Lambda path: TODO

## Access denied test

TODO paste

## Last 10 lines of /var/log/cv-sync.log

TODO paste

## Written answers

**Q1.** TODO question text

TODO

**Q2.** TODO question text

TODO

**Q3.** TODO question text

TODO

**Q4.** TODO question text

TODO

**Q5.** TODO question text

TODO

## Sources and adaptations

TODO
