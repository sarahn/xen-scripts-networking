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

start_filter_eb() {

  iptables -P FORWARD ACCEPT
  iptables -F FORWARD

  ebtables -P FORWARD DROP
  ebtables -F FORWARD
  ebtables -X 

  ebtables -N in-dev-rules -P DROP
  if [ ${antispoof} = 'yes' ] ; then
    ebtables -A in-dev-rules -i ${pdev} -j ACCEPT
    ebtables -A in-dev-rules -i ${vif0} -j ACCEPT
  else
    ebtables -A in-dev-rules -j ACCEPT
  fi

  if [ ${vifoutfilter} = 'yes' ] ; then
 	  ebtables -A FORWARD -o ${pdev} -j in-dev-rules
	  ebtables -A FORWARD -o ${vif0} -j in-dev-rules
  else
  	ebtables -A FORWARD -j in-dev-rules
  fi
}

stop_filter_eb() {
  ebtables -P FORWARD ACCEPT
  ebtables -F FORWARD
	ebtables -X 
}

filter_eb() {

  if ! ebtables -L &> /dev/null
  then
    log err "ebtables not installed. This may affect networking for guest domains."
  fi

  case "$command" in
    start)
	  start_filter_eb
	  ;;
    
    stop)
	  stop_filter_eb
	  ;;

    status)
	  ;;

    *)
	  echo "Unknown command: $command" >&2
	  echo 'Valid commands are: start, stop, status' >&2
   esac
}
