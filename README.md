# HTB_init
-under development-

Standard enumeration on a new HTB Box

```
usage: ./htb_init.sh <ip adress> <name>
example usage: ./htb_init.sh 10.129.236.3 intelligence
```
##
It needs to run with root privileges as it modifies your /etc/hosts file and runs different nmap scans.

The script uses GoBuster which is not installed on a fresh Kali Linux. 

We recommend to have a look at our [script](https://github.com/NocentSec/Kali_VM_init) for fresh Kali setups to get common tools and scripts.


_____________________________
## Implemented Functionality

- adds target to /etc/hosts
- directory for relevant outputs
- performs nmap scan(s)
- performs directory and file scan on found http/https ports with GoBuster
- performs subdomain scan with FFUF, adding subdomains to /etc/hosts
- automated selection of thread options for simultaneous scans  

__
- used tools: nmap, FFUF, GoBuster

## Planned Functionality

- perform scans on found (common) protocols/ports (like smb, ftp...)
- better output for quick overview of scans
