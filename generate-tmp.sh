#!/usr/bin/env bash
set -eou pipefail

tmp_dir=${tmp_dir:-tmp}

cd "$(dirname "$0")"
! [ "${PWD##*/}" = "$tmp_dir" ] || {
	echo Current dir is \"$tmp_dir\". Aborting!
	exit 1
}
origin=$(git remote get-url origin)
new_origin=${origin%.git}
new_origin=${new_origin%/*}
new_origin=$new_origin/${tmp_dir}.git
cd ..
[ -d "$tmp_dir" ] && {
  echo Directory \"$tmp_dir\" already exists. Aborting!
  exit 1
}
cp -a "$OLDPWD" "$tmp_dir"
cd "${tmp_dir}"
git remote set-url origin $new_origin
./publish-to-gh-pages.sh
