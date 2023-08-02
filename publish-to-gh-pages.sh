#!/usr/bin/env bash
log=$(mktemp)

cd "$(dirname "$0")"

d=$(date -Is)

./update-history.sh "$d"

echo -n "Republishing this repository ... "

{
  origin=$(git remote get-url origin)
  rm -rf .git
  git init -b gh-pages
  git add -A
  git remote add origin $origin
  git commit -m "Published at $d"
  git push -f -u origin gh-pages
} &> $log && echo Ok! || echo -n "Error!\n$(cat $log)"
