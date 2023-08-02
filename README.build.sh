#!/usr/bin/env bash
set -eou pipefail

my_variables=false
my_variables_file=${my_variables_file:-my-variables.adoc}

cd "$(dirname "$0")"

! [[ $my_variables_file = *" "* ]] || {
  echo Do not use spaces in the variable \$my_variables_file!
  exit 1
}

! [ -f "$my_variables_file" ] || {
  my_variables=true
  adoc_attrs="-a my-variables=${my_variables_file}"
}

asciidoctor ${adoc_attrs:-} README.adoc -o index.html
