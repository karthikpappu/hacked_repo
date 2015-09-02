#/bin/bash

# Validate chef cookbook by running:
# - foodcritic
# - test kitchen

# Requirements:
# chefdk installed
# kitchen ec2 driver

# Check if the current folder is a cookbook

if [[ ! -f metadata.rb ]];then
	echo "The current folder does not seem to be a cookbook. No metadata.rb found!"
	exit 1
fi

## Foodcritic
echo "Running foodcritic..."
foodcritic -f any .
RETVAL=$?
if [[ "$RETVAL" != "0" ]];then
	echo "foodcritic run failed. exiting..."
	exit 1
fi
echo "Completed foodcritic."

if [[ -f .kitchen.yml ]];then
	kitchen test all
else
	echo "No kitchen config."
fi
RETVAL=$?
if [[ "$RETVAL" != "0" ]];then
	echo "Test kitchen run failed. exiting..."
	exit 1
fi
echo "Completed Test kitchen."
