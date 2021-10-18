#!/bin/bash
###################################################################
#Script Name	:WorkingTitle: htb_init.sh
#Description	:This script enumerates HTB machines by using various tools.
#Args           :<ip> <name>
#Author       	:NocentSec (https://github.com/NocentSec)
#Email         	:contact@nocent.xyz
###################################################################

## CONFIG uncomment as desired

## WORKING DIRECTORY CONFIG uncomment one
#PATHSET="$HOME/";
PATHSET="$HOME/Desktop/";
#PATHSET="$HOME/Documents/";
#PATHSET="$HOME/Downloads/";

## DONT CHANGE ANYTHING BELOW THIS

## colors
red=$(tput setaf 196)
green=$(tput setaf 34)
blue=$(tput setaf 27)
reset=$(tput sgr0)

sudo echo "$red""NocentSec Box Scanner$reset"

programname=$0

function usage {
    echo "usage: $programname <ip adress> <name>"
    echo "example usage: $programname 10.129.236.3 intelligence"
    exit 1
}

function prompt_continue {
	read -p "Do you want to continue anyways? [Y/n] " yn
    case $yn in
        [Yy]* ) :;;
        * ) echo "[-]Abort.";exit 1;;
    esac
}

## preps

function check_usage {

	[ -z $1 ] && { usage; }

	## check internet connection
	ping -c 1 1.1.1.1 -W 1 >/dev/null && : || (echo -e "$red""[-]Network problems, please check your internet connection.$reset"; prompt_continue;)


	## check if valid ip and name
	if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
	then
		ip=$1
		if [[ $2 =~ [a-zA-Z]+$ ]];
		then
			name=$2
		else
			echo "$red""[-]ERR: Please check your input.$reset"
			usage;
			exit 1
		fi
	else
		if [[ $1 =~ [a-zA-Z]+$ ]];
		then
			name=$1
			if [[ $2 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];
			then
				ip=$2
			else
				echo "$red""[-]ERR: Please check your input.$reset"
				usage;
				exit 1
			fi
		else
			echo "$red""[-]ERR: Please check your input.$reset"
			usage;
			exit 1
		fi
	fi

	echo "$green""Name: $name"
	echo "IP: $ip""$reset"

	## check if machine is reachable
	ping -c 1 $ip -W 1 >/dev/null && : || (echo "$red""[-]Host seems to be down, please check your vpn connection.$reset"; prompt_continue;)
}

function load_dependencies {
	echo "$blue""[+]Downloading dependencies$reset"
	## downloading enumeration dependencies
	  ## ffuf
	wget -O "/tmp/subdomains.txt" https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-20000.txt >/dev/null 2>&1
	  ## gobuster
	wget -O "/tmp/directories.txt" https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt >/dev/null 2>&1
}

function add_to_hosts {
	## add to hosts file
	sed "/$ip/d" /etc/hosts | sudo tee /etc/hosts > /dev/null;
	sed "/$name/d" /etc/hosts | sudo tee /etc/hosts > /dev/null;
	echo -e $ip"\t"$name".htb" | sudo tee -a /etc/hosts > /dev/null;
}

function create_working_dir {
	## make directory for new machine
	PATHSET="${PATHSET}$name";
	mkdir $PATHSET > /dev/null 2>&1
}

## enum functions

function net_scan {
	sudo nmap -sS -sV -sC $ip -oN $PATHSET/nmap.txt > /dev/null && echo -e "$green""\n════════════════════════════════════╣ PORTS & SERVICES ╠════════════════════════════════════\n$reset" && 
	tail -n +5 $PATHSET/nmap.txt | head -n -3
}

function subdomain_scan {

	local -n subports=$2
	for i in "${subports[@]}"
	do
		function add_subs {	
		SUBS=$(grep -w "$1://$name.htb:$i/ |" $PATHSET/${i}subdomains.md | cut -d " " -f4 | sed "s/$/."$name".htb/" | tr '\n' ' ')
		sudo sed -i "s/$name.htb/$name.htb $SUBS/" /etc/hosts
		if [ -z "$SUBS" ]
		then
			echo "$red""[-]No subdomains found.$reset"
		else
			echo "$green""[+]subs added to /etc/hosts: $SUBS$reset"
		fi
		}

		ffuf -w /tmp/subdomains.txt -u "$1://"$name".htb:$i/" -H "Host: FUZZ."$name".htb" -ac -s -t $3 -o "$PATHSET/$i""subdomains.md" -of md >/dev/null 2>&1 &&
		echo -e "$green""\n════════════════════════════════════╣ SUBDOMAINS ON PORT $i ╠════════════════════════════════════\n$reset" && tail -n +8 "$PATHSET/$i""subdomains.md" &&
		add_subs $*;
	done
}

function dir_file_scan {

	local -n dirports=$2
	for i in "${dirports[@]}"
	do
		gobuster dir -w /tmp/directories.txt -u "$1://"$name".htb:$i/" -t $3 -x php,html,txt -b 404,502 -o "$PATHSET/$i""directories_n_files.txt" >/dev/null 2>&1 &&
		echo -e "$green""\n════════════════════════════════════╣ DIRECTORIES & FILES ON PORT $i ╠════════════════════════════════════\n$reset" &&
		cat "$PATHSET/"$i"directories_n_files.txt"
	done

}

function smb_enumeration {

	local -n smbports=$1
	for i in "${smbports[@]}"
	do
		smbclient --no-pass -L $ip -p $i > "$PATHSET/$i""samba.txt" &&
		echo -e "$green""\n════════════════════════════════════╣ SMB NULL USER ON PORT $1 ╠════════════════════════════════════\n$reset" &&
		cat "$PATHSET/$i""samba.txt"
	done
}


function run_scanner {
	## gen portmap
	sudo nmap $ip -sV -oN $PATHSET/qnmap.txt > /dev/null 
	declare -A portmap
	ports=($(awk -F '/tcp' '{print $1,$2}' $PATHSET/qnmap.txt | grep open | awk '{print $1}'))
	protocols=($(awk -F '/tcp' '{print $1,$2}' $PATHSET/qnmap.txt | grep open | awk '{print $3}'))
	for i in "${!ports[@]}"
	do
	 portmap[${ports[i]}]=${protocols[i]}
	done


	http=()
	https=()
	smb=()
	#protocol X
	for i in "${!portmap[@]}"
	do
		case ${portmap[$i]} in
			"http")
				http=(${http[@]} $i)
				;;
			"https"|"ssl/http")
				https=(${https[@]} $i)
				;;
			"microsoft-ds")
				smb=(${smb[@]} $i)
				;;
			#protocol X)
		esac
	done

	## calculate threads to use for directory enumeration, 200/num ports
	max_threads=1;
	((max_threads = 200 / (("${#http[@]}" + "${#https[@]}"))))

	## general
	net_scan &

	## on http 
	subdomain_scan "http" http $max_threads &
	dir_file_scan "http" http $max_threads &

	## on https
	subdomain_scan "https" https $max_threads &
	dir_file_scan "https" https $max_threads &

	## on smb
	smb_enumeration smb &
	echo "$green""[+]Enumerating$reset"

	## on protocol X

	wait $(jobs -p)
}


## run part

check_usage $*;
load_dependencies;
create_working_dir;
add_to_hosts;

## Enum

echo "$blue""[+]Starting Initial Portscan$reset"
run_scanner;

## Aftermath
	## deleting temporary files
rm -f "/tmp/subdomains.txt"
rm -f "/tmp/directories.txt"

echo -e "$red""\n\ndone$reset"
