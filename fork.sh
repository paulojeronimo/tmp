#!/usr/bin/env bash
set -eou pipefail

{
	log=$(mktemp)
	origin=${origin:-https://github.com/paulojeronimo/tmp-history}
	history_dir=${history_dir:-$(basename $origin)}
	[ "${github_user:-}" ] || {
    while IFS= true
    do
      read -p "Enter your github user: " -r github_user
      if [ "${github_user}" ]
      then
        read -p "Confirm \"$github_user\"? (Y|N) " -r -n 1
        echo
        ! [[ $REPLY =~ ^[Yy]$ ]] || break
      fi
    done
	}

	echo -n "Cloning from $origin to $history_dir ... "
	git clone --depth 1 $origin $history_dir &> $log && echo Ok! || {
		echo -e "Fail!\n$(cat $log)"
		exit 1
	}

	cd $history_dir
	echo Creating my-fork.json ...
	cat > my-fork.json <<-EOF
	{
	  "origin": "$(git remote get-url origin)",
	  "date": "$(date -Is)",
	  "commit": "$(git rev-parse HEAD)"
	}
	EOF

	new_origin=git@github.com:$github_user/$history_dir.git
	echo -n "Pushing $new_origin ... "
	rm -rf .git changes.txt
	{
		git init
		git add .
		git commit -m 'Initial commit'
		git branch -M main
		git remote add origin $new_origin
		git push -f -u origin main
	} &> /dev/null && echo Ok! || echo Fail!
}
