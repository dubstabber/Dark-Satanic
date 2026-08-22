#!/usr/bin/env python3
"""Print N fresh Godot-style resource uids (uid://<13 base-36 chars>). Usage: tools/new_uid.py [N]"""
import random, string, sys
n = int(sys.argv[1]) if len(sys.argv) > 1 else 1
for _ in range(n):
    body = random.choice(string.ascii_lowercase) + "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(12))
    print("uid://" + body)
