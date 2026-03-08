#!/usr/bin/env python3

import subprocess
import re

def run(cmd):
    subprocess.run(cmd, shell=True, check=True)

def get_latest_tag():
    try:
        tag = subprocess.check_output(
            "git describe --tags --abbrev=0",
            shell=True
        ).decode().strip()
        return tag
    except:
        return "v0.0.0"

def bump_version(tag, kind):
    m = re.match(r"v(\d+)\.(\d+)\.(\d+)", tag)
    major, minor, patch = map(int, m.groups())

    if kind == "major":
        major += 1
        minor = 0
        patch = 0
    elif kind == "minor":
        minor += 1
        patch = 0
    elif kind == "patch":
        patch += 1

    return f"v{major}.{minor}.{patch}"

release_type = input("Release type (stable/canary): ").strip()
work_type = input("Work type (patch/minor/major): ").strip()
notes = input("Write release notes: ").strip()

default_apk = "./build/app/outputs/apk/release/app-release.apk"
debug_apk = "./build/app/outputs/apk/debug/app-debug.apk"
apk_input = input(f"APK path, 'debug', or 'release' [{default_apk}]: ").strip()
if apk_input == "debug":
    apk_path = debug_apk
elif apk_input == "release" or not apk_input:
    apk_path = default_apk
else:
    apk_path = apk_input

latest = get_latest_tag()
new_tag = bump_version(latest, work_type)

if release_type == "canary":
    new_tag = new_tag + "-canary"

print("Creating release:", new_tag)

run(f"git tag -a {new_tag} -m \"{notes}\"")
run(f"git push origin {new_tag}")

run(
    f"gh release create {new_tag} {apk_path} "
    f"--title \"{new_tag}\" "
    f"--notes \"{notes}\""
)

print("Release created:", new_tag)