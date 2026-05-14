#!/usr/bin/env bash
set -o pipefail

[ "$1" ] || { echo A date is required!; exit 1; }

history_dir=${history_repo:-../tmp-history}
changes_file="$history_dir"/changes.txt

cd "$(dirname "$0")"
[ -d "$history_dir" ] && {
  echo Directory history_dir is $(cd "$PWD/$history_dir"; pwd)
} || {
  echo Directory \"$PWD/$history_dir\" does not exists. Aborting!
  exit 1
}

declare -A history_files
cd "$history_dir"
for f in $(find . -type f ! \( -name $(basename "$changes_file") -o -path './.git/*' \))
do
  history_files[$f]=1
done
cd "$OLDPWD"

filter() {
  while IFS= read -r f
  do
    [ "${history_files[$f]}" ] || [ "$f" = './index.html' ] || echo $f
  done
}

for f in ${!history_files[@]}; do cp "$f" "$history_dir"/; done

echo -e "--> Date and time <--\n$1" > "$changes_file"

cd "$history_dir"
persistent=$(mktemp)
echo -e "\n--> Persistent files changes <--" >> "$changes_file"
git add .
git status --short | grep -v $(basename "$changes_file") | tee $persistent >> "$changes_file"
cd "$OLDPWD"

temporary=$(mktemp)
echo -e "\n--> Temporary files changes <--" >> "$changes_file"
git add .
git status --short | grep -v $(basename "$changes_file") > $temporary

grep -vf $persistent $temporary >> "$changes_file"

echo -e "\n--> Temporary files hashes <--" >> "$changes_file"
rm -f "$(basename "$changes_file")"
find . -type f ! -path './.git/*' | filter | sort | xargs sha256sum >> "$changes_file"
cp "$changes_file" .

log=$(mktemp)
cd "$history_dir"
echo -n "Updating history_dir repository ($(git remote get-url origin)) ... "
{
  git add .
  git commit -m "Updated at $1"
  git push
} &> $log && echo Ok! || echo -n "Error!\n$(cat $log)"

echo "Content of '$changes_file' (between 4 dashes):"
echo -e "----\n$(cat "$changes_file")\n----"
