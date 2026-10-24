import base64
import json
import os
import time

import boto3

s3 = boto3.client("s3")

# path -> (S3 key suffix, content type, binary?)
FILES = {
    "/": ("index.html", "text/html; charset=utf-8", False),
    "/index.html": ("index.html", "text/html; charset=utf-8", False),
    "/style.css": ("style.css", "text/css", False),
    "/cv.pdf": ("cv.pdf", "application/pdf", True),
}


def respond(status, body, ctype, extra=None, b64=False):
    headers = {"Content-Type": ctype, **(extra or {})}
    return {"statusCode": status, "headers": headers, "body": body, "isBase64Encoded": b64}


def handle(event, context):
    path = event["rawPath"]
    if path not in FILES:
        return respond(404, "<html><body><h1>Not found</h1></body></html>", "text/html; charset=utf-8")
    suffix, ctype, binary = FILES[path]
    try:
        data = s3.get_object(Bucket=os.environ["BUCKET"], Key=os.environ["PREFIX"] + suffix)["Body"].read()
    except Exception:
        return respond(500, "Internal error fetching content", "text/plain; charset=utf-8")
    if binary:
        return respond(200, base64.b64encode(data).decode(), ctype, b64=True)
    text = data.decode("utf-8")
    if suffix == "index.html":
        text = text.replace("{{HOSTED_ON}}", "Lambda " + context.function_name)
        return respond(200, text, ctype, {"Cache-Control": "max-age=60"})
    return respond(200, text, ctype)


def lambda_handler(event, context):
    start = time.time()
    resp = handle(event, context)
    print(json.dumps({
        "fn": context.function_name,
        "path": event["rawPath"],
        "status": resp["statusCode"],
        "ms": int((time.time() - start) * 1000),
    }))
    return resp
