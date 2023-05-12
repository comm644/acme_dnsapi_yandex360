#!/usr/bin/bash
# Author: node644@gmail.com
# 12 may 2023
# report bugs at https://github.com/comm644/acme_dnsapi_yandex360
# based on dns_yadex.sh big thanks to non7top@gmail.com 

# Values to export:
# export Y360_Token="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# export Y360_OrgId="xxxxxx"

# Sometimes cloudflare / google doesn't pick new dns records fast enough.
# You can add --dnssleep XX to params as workaround.

########  Public functions #####################

#Usage: dns_myapi_add   _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_yandex_360_add() {
  fulldomain="${1}"
  txtvalue="${2}"
  subdomain=`echo $fulldomain| cut -d'.' -f 1`
  domain=`echo $fulldomain | sed s/${subdomain}\.//`
  
  
  _debug "Calling: dns_yandex_360_add() '${fulldomain}' '${txtvalue}'"

  # define uri store settings  
  _Y360_credentials || return 1
  # load registred records  
  _Y360_get_record_ids || return 1
  # remove old records before adding  
  dns_yandex_360_rm $fulldomain  || return 1
  
  _debug "list DNS records: ${record_ids}"
  
  
  data="{
  \"name\": \"${subdomain}\",
  \"text\": \"${txtvalue}\",
  \"ttl\": 300,
  \"type\": \"TXT\"
}"


  result="$(_post "${data}" "${uri}" | _normalizeJson)"
  _debug "Result: $result"

  if ! _contains "$result" '"recordId"'; then
      return 1
  fi
}

#Usage: dns_myapi_rm   _acme-challenge.www.domain.com
dns_yandex_360_rm() {
  fulldomain="${1}"
  subdomain=`echo $fulldomain| cut -d'.' -f 1`
  domain=`echo $fulldomain | sed s/${subdomain}\.//`
  
  
  _debug "Calling: dns_yandex_rm() '${fulldomain}'"

  _Y360_credentials || return 1

#  _PDD_get_domain "$fulldomain" || return 1
#  _debug "Found suitable domain: $domain"

  _Y360_get_record_ids "${domain}" "${subdomain}" || return 1
  _debug "Record_ids: $record_ids"

  for record_id in $record_ids; do
    data="{}"
    deleteUri="${uri}/${record_id}"
    result="$(_post "${data}" "${deleteUri}" "" "DELETE" | _normalizeJson)"
    echo ${result}
    _debug "Result: $result"

    if ! _contains "$result" '{}'; then
      _info "Can't remove $subdomain from $domain."
    else 
      _debug "Record ${record_id} deleted."
    fi
  done
}

####################  Private functions below ##################################

_Y360_get_domain() {
#todo rewrite it
  subdomain_start=1
  while true; do
    domain_start=$(_math $subdomain_start + 1)
    domain=$(echo "$fulldomain" | cut -d . -f "$domain_start"-)
    subdomain=$(echo "$fulldomain" | cut -d . -f -"$subdomain_start")

    _debug "Checking domain $domain"
    if [ -z "$domain" ]; then
      return 1
    fi

    uri="https://pddimp.yandex.ru/api2/admin/dns/list?domain=$domain"
    result="$(_get "${uri}" | _normalizeJson)"
    _debug "Result: $result"

    if _contains "$result" '"success":"ok"'; then
      return 0
    fi
    subdomain_start=$(_math $subdomain_start + 1)
  done
}

_Y360_credentials() {
  if [ -z "${Y360_Token}" ]; then
    Y360_Token=""
    Y360_OrgId=""
    _err "You need to export Y360_Token=xxxxxxxxxxxxxxxxx."
    _err "You need to export Y360_OrgId=xxxxxxxxxxxxxxxxx.  See cookies admin.yandex.ru" 
    _err "You can get it at https://yandex.ru/dev/api360/doc/concepts/intro.html"
    return 1
  else
    _saveaccountconf Y360_Token "${Y360_Token}"
    _saveaccountconf Y360_OrgId "${Y360_OrgId}"
  fi
  
  export _H1="Authorization: OAuth ${Y360_Token}"
  uri="https://api360.yandex.net/directory/v1/org/${Y360_OrgId}/domains/${domain}/dns"
}

_Y360_get_record_ids() {
  _debug "Check existing records for $subdomain"

  result="$(_get "${uri}?perPage=100" | _normalizeJson)"
  _debug "Result: $result"

  record_ids=$(echo "$result" | _egrep_o "{[^{]*\"name\":\"_acme-challenge\"[^}]*}" | sed -n -e 's#.*"recordId":\([0-9]*\).*#\1#p')
  _debug "Found records ids:: $record_ids"
}
