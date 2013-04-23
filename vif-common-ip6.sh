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
# License along with this library; iantispoof=${antispoof:-no}

antispoof=${antispoof:-no}
vifoutfilter=${vifoutfilter:-no}

ip=${ip:-}
ip=$(xenstore_read_default "$XENBUS_PATH/ip" "$ip")

function frob_ip6table()
{
  if [ "$command" == "online" ]
  then
    local c="-A"
  else
    local c="-D"
  fi

  ip6tables "$c" in-dev-rules -m physdev --physdev-in "$vif" "$@" -j ACCEPT \
    2>/dev/null ||
    [ "$c" == "-D" ] ||
    log err \
     "ip6tables $c in-dev-rules -m physdev --physdev-in $vif $@ -j ACCEPT failed.
If you are using ip6tables, this may affect networking for guest domains."
}

function frob_ip6table_outdevrules()
{
  if [ "$command" == "online" ]
  then
    local c="-A"
  else
    local c="-D"
  fi

  ip6tables "$c" FORWARD -m physdev --physdev-out "$vif" "$@" -j in-dev-rules \
    2>/dev/null ||
    [ "$c" == "-D" ] ||
    log err \
     "ip6tables $c FORWARD -m physdev --physdev-out $vif $@ -j in-dev-rules failed.
If you are using iptables, this may affect networking for guest domains."
}

##
# Add or remove the appropriate entries in the iptables.  With antispoofing
# turned on, we have to explicitly allow packets to the interface, regardless
# of the ip setting.  If ip is set, then we additionally restrict the packets
# to those coming from the specified networks, though we allow DHCP requests
# as well.
#
function handle_ip6table()
{
  # Check for a working iptables installation.  Checking for the iptables
  # binary is not sufficient, because the user may not have the appropriate
  # modules installed.  If iptables is not working, then there's no need to do
  # anything with it, so we can just return.
  if ! ip6tables -L -n &> /dev/null
  then
    return
  fi

  claim_lock "ip6tables"

  echo "$ip" > grep ":" &> /dev/null
  has_ipv6=$?

  if [ "$has_ipv6" = "0"  -a ${antispoof} = 'yes' ]
  then
      local addr
      for addr in $ip
      do
        if echo $addr | grep : &> /dev/null; then
          frob_ip6table -s "$addr"
          if echo $addr | grep -v "/" &> /dev/null; then
            local solicited=$(ipv6calc --addr_to_fulluncompressed $addr | \
              cut -f 1 -d "/" | \
              awk -F":" '{print "FF02::1:ff" substr($7 ,length($7)-1) ":" $8} ')
            frob_ip6table_outdevrules -d "$solicited"
          fi
        fi
      done

      # Always allow the domain to talk to a DHCP server.
      frob_ip6table -p udp --sport 68 --dport 67
  else
      # No IP addresses have been specified, so allow anything.
      frob_ip6table
  fi

  if [ "$has_ipv6" = "0" -a ${vifoutfilter} = 'yes' ]
  then
      local addr
      for addr in $ip
      do
        if echo $addr | grep : &> /dev/null; then
          frob_ip6table_outdevrules -d "$addr"
        fi
      done
  else
      frob_ip6table_outdevrules
  fi

  release_lock "ip6tables"
}
