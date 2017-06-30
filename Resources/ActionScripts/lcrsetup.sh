#!/usr/bin/env bash

# put R code in users home directory
git clone  -b spark --single-branch  https://github.com/Microsoft/r-server-loan-credit-risk.git  loans
cp loans/RSparkCluster/* /home/$1
chmod 777 /home/$1/*.R
rm -rf loans
sed -i "s/XXYOURSQLPW/$2/g" /home/$1/*.R

# Configure edge node as one-box setup for R Server Operationalization
/usr/local/bin/dotnet /usr/lib64/microsoft-r/rserver/o16n/9.1.0/Microsoft.RServer.Utils.AdminUtil/Microsoft.RServer.Utils.AdminUtil.dll -silentoneboxinstall "$2"