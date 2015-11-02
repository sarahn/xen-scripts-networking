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

vifoutfilter=${vifoutfilter:-yes}
antispoof=${antispoof:-yes}

start_filtering_ip6() {

  #Always enable ip6tables filtering for the bridge.

  sysctl -w net.bridge.bridge-nf-call-ip6tables=1
  ip6tables -P FORWARD DROP
  ip6tables -F FORWARD
	
  ip6tables -N in-dev-rules

  if [ ${antispoof} = 'yes' ] ; then
    ip6tables -A in-dev-rules -m physdev --physdev-in ${pdev} -j ACCEPT
    ip6tables -A in-dev-rules -m physdev --physdev-in ${vif0} -j ACCEPT
    ip6tables -A in-dev-rules -p ipv6-icmp --icmpv6-type 134 -j DROP
    ip6tables -A in-dev-rules -p ipv6-icmp --icmpv6-type 137 -j DROP
  else
		ip6tables -A in-dev-rules -j ACCEPT
  fi

  if [ ${vifoutfilter} = 'yes' ] ; then
    ip6tables -A FORWARD -d fe80::/10 -p udp --dport 546 -j DROP
 	  ip6tables -A FORWARD  -m physdev --physdev-out ${pdev} -j in-dev-rules
	  ip6tables -A FORWARD  -m physdev --physdev-out ${vif0} -j in-dev-rules
    ip6tables -A FORWARD -d ff02::1 -j in-dev-rules
  else
  	ip6tables -A FORWARD -j in-dev-rules
  fi
}

stop_filtering_ip6() {
  ip6tables -P FORWARD ACCEPT
  ip6tables -F FORWARD

	ip6tables -F in-dev-rules
	ip6tables -X in-dev-rules
}


filter_ip6() {

  if ! ip6tables -L &> /dev/null
  then
    log err "ip6tables not installed. This may affect networking for guest domains."
  fi

  case "$command" in
    start)
	  start_filtering_ip6
	  ;;
    
    stop)
	  stop_filtering_ip6
	  ;;

    status)
	  ;;

    *)
	  echo "Unknown command: $command" >&2
	  echo 'Valid commands are: start, stop, status' >&2
   esac
}
