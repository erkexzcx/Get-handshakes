gethandshakes.sh
================
Description:
-----------
This is a script, which is used to automaticall collect handshakes (\*.hccap files) from all around discovered WiFis. Script automatically detects all available wlan interfaces and will ask you step by step what would you like to do.

Script was primarily tested and designed to work on Arch and Kali Linux distributions, but I believe it should work in any Linux distribution.

Requirements:
------------
1. Any Linux distribution
2. Configured, working and connected WiFi adapter. It must support monitoring mode!
3. Packages `aircrack-ng net-tools xterm` and Linux standard core packages (bash, grep, awk, sed, ls......).

Installation:
------------
1. Open terminal in your favorite directory (e.g. ~/Downloads/)
2. Run the following command to download:
```
wget https://raw.githubusercontent.com/erkexzcx/Get-handshakes/master/gethandshakes.sh
```
3. Make this script executable:
```
chmod +x gethandshakes.sh
```
Usage:
-----
1. Open terminal (fullscreen) in the same directory where is gethandshakes.sh script located.
2. Run this script:
```
./gethandshakes.sh
```
