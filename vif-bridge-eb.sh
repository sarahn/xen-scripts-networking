#
# Copyright (c) 2013 prgmr.com
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of version 2.1 of the GNU Lesser General Public
# License as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

antispoof=${antispoof:-yes}
vifoutfilter=${vifoutfilter:-yes}
vifoutfilter_allowip6=${vifoutfilter_allowip6:-yes}

mac=${mac:-}
mac=$(xenstore_read_default "$XENBUS_PATH/mac" "$mac")

function handle_ebtable()
{
  if ! ebtables -L &> /dev/null
  then
    return
  fi

  claim_lock "ebtables"

  claim_lock "iptables"
  iptables -F FORWARD
  release_lock "iptables"

  echo "$ip" | grep "\." &> /dev/null
  has_ipv4=$?

  if [ "$command" != "online" ]; then
    if [ ${vifoutfilter} = 'yes' ] ; then
      ebtables -D FORWARD -o "$vif" -j "$vif"-out 
      ebtables -X "$vif"-out
    fi
    ebtables -D in-dev-rules -i "$vif" -j "$vif"-in
    ebtables -X "$vif"-in
    release_lock "ebtables"
    success
    return
  fi

  if [ ${vifoutfilter} = 'yes' ] ; then
    ebtables -N "$vif"-out -P DROP
    ebtables -A FORWARD -o "$vif" -j "$vif"-out
    if [ "$has_ipv4" = "0" ] 
    then
      for addr in $ip
      do
        if echo $addr | grep "\." &>/dev/null; then
          ebtables -A "$vif"-out -p ip4 --ip-dst "$addr" -j in-dev-rules
          ebtables -A "$vif"-out -p arp --arp-ip-dst "$addr" -j in-dev-rules
        fi
      done
    else 
      ebtables -A "$vif"-out -p ip4 -j in-dev-rules
      ebtables -A "$vif"-out -p arp -j in-dev-rules
    fi
    if [ "$vifoutfilter_allowip6" = 'yes' ] 
    then
      ebtables -A "$vif"-out -p ip6 -j in-dev-rules
    fi
  fi


  ebtables -N "$vif-in" -P ACCEPT
  ebtables -A in-dev-rules -i "$vif" -j "$vif"-in

  if [ "$mac" != "" -a ${antispoof} = 'yes' ]
  then
    ebtables -A "$vif-in" -s ! "$mac" -j DROP
  fi


  if [ "$has_ipv4" = "0" -a ${antispoof} = 'yes' ] 
  then
    local addr
    for addr in $ip ; do
      if echo $addr | grep "\." &> /dev/null; then
        ebtables -A "$vif"-in -p ip4 --ip-src "$addr" -j ACCEPT
        ebtables -A "$vif"-in -p arp --arp-ip-src "$addr" --arp-mac-src "$mac" -j ACCEPT
      fi
    done
    ebtables -A "$vif"-in -p ip4 --ip-protocol udp \
      --ip-source-port 68 --ip-destination-port 67 -j ACCEPT
    ebtables -A "$vif"-in -p ip4 -j DROP
    ebtables -A "$vif"-in -p arp -j DROP
  fi
  release_lock "ebtables"
}
