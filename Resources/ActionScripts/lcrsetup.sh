#!/usr/bin/env bash

# put R code in users home directory
git clone  --single-branch  https://github.com/Microsoft/r-server-loan-credit-risk.git  loans
cp loans/RSparkCluster/* /home/$1
chmod 777 /home/$1/*.R
rm -rf loans
sed -i "s/XXYOURSQLPW/$2/g" /home/$1/*.R

# Configure edge node as one-box setup for R Server Operationalization
az extension add --source /opt/microsoft/mlserver/9.3.0/o16n/azure_ml_admin_cli-0.0.1-py2.py3-none-any.whl --yes
az ml admin node setup --onebox --admin-password $2 --confirm-password $2

# turn off telemetry 
sed -i 's/options(mds.telemetry=1)/options(mds.telemetry=0)/g' /usr/lib64/microsoft-r/3.3/lib64/R/etc/Rprofile.site
sed -i 's/options(mds.logging=1)/options(mds.logging=0)/g' /usr/lib64/microsoft-r/3.3/lib64/R/etc/Rprofile.site

#Run R scripts
cd /home/$1

#run install.R
Rscript install.R

#run step0_data_generation.R
Rscript development_main.R