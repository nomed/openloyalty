#!/usr/bin/env python3
"""Exercise synthetic admin, customer, and seller login endpoints without logging tokens."""
import json
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request

api_base = sys.argv[1].rstrip("/")
checks = (
    ("admin", "admin", "open"),
    ("customer", "user@oloy.com", "loyalty"),
    ("seller", "john@doe.com", "open"),
)
failed = False
for role, username, password in checks:
    request = urllib.request.Request(
        api_base + "/" + role + "/login_check",
        data=urllib.parse.urlencode({"_username": username, "_password": password}).encode(),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.loads(response.read())
        if not isinstance(payload.get("token"), str) or not payload["token"]:
            failed = True
            print("FAIL " + role + " login: response omitted token")
        else:
            print("OK " + role + " login")
    except (urllib.error.URLError, ValueError, socket.timeout) as error:
        failed = True
        status = str(getattr(error, "code", "request error"))
        print("FAIL " + role + " login: " + status)
sys.exit(1 if failed else 0)
