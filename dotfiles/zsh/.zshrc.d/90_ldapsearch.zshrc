function ads-custom () {
  supplied_url="$1"
  substring="://"
  if test "${string#*$substring}" != "$string"; then
    ad=$supplied_url
  else
    ad="ldaps://${supplied_url}"
  fi
  ldapsearch \
    -Q \
    -H "$ad" \
    -LLL \
    -E pr=1000/noprompt \
    -o ldif-wrap=no \
    -b "dc=office,dc=atlassian,dc=com" \
    -X dn:cn=$USER,ou=people,dc=office,dc=atlassian,dc=com \
    -Y GSSAPI \
    -O maxssf=0 \
    ${@:2} | \
    awk '{ if ($0 ~ /::/) { cmd="echo "$2" | base64 -D";cmd| getline x;close(cmd); gsub(/::/, ": ", $1); print $1 x } else print $0 }'
}
function ads-all () {
  GREPPY='.'
  while getopts "g:" c
  do
    case $c in
      g) GREPPY=$OPTARG ;;
    esac
  done
  shift $((OPTIND-1))
  (
    dig _ldap._tcp.dc._msdcs.office.atlassian.com SRV +noquestion | \
      grep "IN SRV" | \
      sort | \
      awk '{print $8}' | \
      sed -e 's/.$//'
  ) | while read ad; do
    if ! ads-custom $ad $@ | sed "s/^/${ad}: /" | grep -i -E "$GREPPY"; then
      echo "${ad}:"
    fi
  done
}
function ads-apse1a { ads-custom apse1a-ad01.office.atlassian.com $@; }
function ads-apse2a { ads-custom apse2a-ad01.office.atlassian.com $@; }
function ads-euc1a { ads-custom euc1a-ad01.office.atlassian.com $@; }
function ads-usw2a { ads-custom usw2a-ad01.office.atlassian.com $@; }
function ads-use1a { ads-custom use1a-ad01.office.atlassian.com $@; }
alias ads=ads-apse2a
function ads-csv () {
  ads $@ | \
    grep -v "^#" | \
    grep -v "dn:" | \
    awk -v FS=": " '{print $2}' | \
    awk -v RS='' '{gsub("\n", ","); print}'
}
