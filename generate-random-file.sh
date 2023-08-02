#!/usr/bin/env bash

size=${size:-3}

cd "$(dirname "$0")"
while true
do
  filename=$(cat /dev/random | tr -dc 'a-zA-Z0-9' | fold -w $size | head -n1)
  [ -f $filename ] || break
done

> $filename
echo $filename
