ls 
touch
man
mkdir
chmod
cd 
rm -r
rmdir
vi
#!/bin/bash  or sh or ksh
echo $SHELL
ls -l /bin/sh
which bash
bash --version
which dash
dash --version
-----------------------------------
echo "Login shell: $SHELL"
echo "Current shell: $(ps -p $$ -o comm=)"
echo "/bin/sh points to:"
ls -l /bin/sh

echo "Available shells:"
cat /etc/shells
-------------------------------------
top
nproc
free -h
df -h
set -x
ps -ef
ps -ef | grep "----"
date
awk
cut 
trim
ps -ef | grep "google" | awk -F " " '{print $2}'
set -e
set -o pipefail
curl www.google.com
wget
ls /etc/
find /
sudo su -
trap
linux signals 
trap "echo donot use ctrl+c" SIGNIT
trap "rm -rf *" SIGNIT
wc -l
-------------------------
#!/bin/bash/
x=missisipi
grep -o "s" <<<"$x" | wc -l
---------------------------
vim -r test.txt
alias
break
continue
traceroute
logrotate
