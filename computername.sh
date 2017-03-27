#!/bin/bash

####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	computername.sh -- Changes the computer name of a client computer to a naming convention that you choose
#
# SYNOPSIS
#   There are three parameters used in this script: parameters 4, 5, and 6.  
#   Parameters 4 and 5 are used for the API Username and Password that will be used to grab the list
#   of packages from the JSS. This API user needs CREATE, UPDATE and READ privileges for Packages and 
#   Categories in the JSS. 
#
#	Parameter 6 is used for the JSS URL. This must be written out with the FQDN as well as the port
#   number. For instance, it should be written out like this:
#
#   zen01.jamf.com:8443    for most on premise installs, or
#   zen01.jamfcloud.com    if you are a cloud hosted customer, or have changed your port number to 443.
#
#	Parameter 1, 2, and 3 will not be used in this script, but since they are passed by
#	The Caspeer Suite, we will start using parameters at parameter 4.
#	If no parameter is specified for either parameter 4 or 5, the hardcoded value in the script
#	will be used.  If values are hardcoded in the script for the parameters, then they will override
#	any parameters that are passed by The Casper Suite.
#
# DESCRIPTION
#	This script will change the name of a client computer of your choosing, and is meant to be adapted to
#   your environment. It is using the API of Jamf Pro to grab specific values associated to the computer, 
#   including the username and any 
#
#   This script should be run as part of a policy in your Jamf Pro Server
#
####################################################################################################
#
# HISTORY
#
#	Version: 1.0
#
#	- Created by Chris Schasse on March 24th, 2017
#
####################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
####################################################################################################

# HARDCODED VALUES ARE SET HERE
apiusername=''
apipassword=''
jssurl=''
# The jssurl variable must be the FQDN with the port number. For instance:
# zen01.jamf.com:8443 (or zen01.jamfcloud.com if port number is 443)

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 4 AND, IF SO, ASSIGN TO "apiusername"
if [ "$4" != "" ] && [ "$apiusername" == "" ]; then
    apiusername=$4
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 5 AND, IF SO, ASSIGN TO "apipassword"
if [ "$5" != "" ] && [ "$apipassword" == "" ]; then
    apipassword=$5
fi

# CHECK TO SEE IF A VALUE WAS PASSED IN PARAMETER 6 AND, IF SO, ASSIGN TO "jssurl"
if [ "$6" != "" ] && [ "$jssurl" == "" ]; then
    jssurl=$6
fi

####################################################################################################
# 
# GATHERING API DATA - NO NEED TO MODIFY THIS SECTION
#
####################################################################################################


# Error checking to see if their is connection to the JSS
curl ${JSS}/JSSCheckConnection
if [ $? != 0 ]
then 
	echo "Cannot connect to the JSS. Check the JSS URL and your internet connection." 1>&2
	exit 1
fi

serialnumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
if [ $? != 0 ]; then
	echo "Cannot retrieve Serial Number from Mac. Aborting!" 1>&2
	exit 1
fi

xml=$(curl -u ${apiusername}:${apipassword} ${jssurl}/JSSResource/computers/serialnumber/${serialnumber} -X GET)
echo $xml | grep '<title>Status page</title>'
if [ $? = 0 ]; then
	echo $xml 1>&2
	echo "Cannot access Jamf Pro Server through API. Aborting!" 1>&2
	exit 1
fi

####################################################################################################
# 
# SETTING THE NAMING CONVENTION, MODIFY THIS SECTION AS NEEDED!!!
#
# In this example, I am naming the computer using the USERNAME inside of Jamf Pro and the MODEL, 
# using an abbreviation method I created. For instance, the computer name for a MacBook Pro associated
# to the user jbridges would be: 
#
#      MBP-jbridges
#
# Customize this section as necessary
#
####################################################################################################

# These two variables use the xml gathered from the API call above and parses through it using xpath.
# If you want to grab another attribute of the inventory, just edit the "/computer/location/username" part
# in the middle to target what you want. For example, if you wanted to add the building it was in, 
# you could use this value:
# 
#      building=$(echo $xml | xpath 'string(/computer/location/building)' 2>/dev/null)
#
# Other common attributes include:
# 	/computer/general/name    
#	/computer/general/asset_tag
#	/computer/general/site/name
#	/computer/location/realname
#	/computer/location/email_address
#	/computer/location/phone
#	/computer/location/department

model=$(echo $xml | xpath 'string(/computer/hardware/model)' 2>/dev/null)
username=$(echo $xml | xpath 'string(/computer/location/username)' 2>/dev/null)

# This is a series of IF statements that will rename the model variable captured above into a 
# short name

case $model in
	"MacBook Pro") 	short=MBP
	;;
	"MacBook") 	short=MB
	;;
	"MacBook Air") 	short=MBA
	;;
	"Mac Pro")	short=MP
	;;
	"Mac Mini")	short=MM
	;;
	*)		short=UNK
	;;
esac

computerName=${short}-${username}

####################################################################################################
# 
# SETTING THE COMPUTER NAME, NO NEED TO MODIFY THIS SECTION
#
####################################################################################################

scutil --set HostName $computerName
scutil --set LocalHostName $computerName
scutil --set ComputerName $computerName

echo "Successfully changed Computer, Local, and Host Name to $computerName" 1>&2
exit 0
