#!/bin/bash
# Script to measure cpu and memory usage of node processes on RHEL
# ToDo: 
# 	> add script arguments to define execution/ monitoring duration (DONE)
# 	> make sure to take the right column for cpu and memory by checking the header of the columns (DONE)
# 	> add exit command
# 	> generate a python diagram that compares the result of the current measurements with another csv file

# Create variables for the directory and file path
PRG="$0"
PRGDIR="$(dirname $PRG)"
FILENAME="cpu_$(date +%F_%H%M%S).csv"
DIRPATH=$(cd "$PRGDIR" || exit; pwd)
DURATION=""
DEFAULT_DURATION="120"
CPU_FIELD=0
MEM_FIELD=0

is_numeric() {
	[[ "$1" =~ ^[0-9]$ ]]
}

find_cpu_and_mem_field() {
	IFS=" "
	HEADER_STR=$( top -b -n 1 | grep "CPU" | head -1  )
	FIRST_CHAR=$(printf %.1s "$HEADER_STR")
	COUNTER=1

	if [ "$FIRST_CHAR" = " " ]; then
    		(( COUNTER++))
	fi

	read -ra HEADER_ARR <<< "$HEADER_STR"

	for STR in "${HEADER_ARR[@]}"
	do 
    		if [[ "$STR" =~ "CPU" ]]; then
        		CPU_FIELD=$COUNTER
    		fi

    		if [ "$STR" = "%MEM" ]; then
        		MEM_FIELD=$COUNTER
    		fi

    	(( COUNTER++ ))
	done
}

# Check if duration is set
if [ $# -eq 1 ]; then
	if [is_numeric "$1"]; then
		echo "Setting duration to $1"
		DURATION="$1"
	else
		echo "Error: Duration argument must be a number."
		exit 1
	fi
else
	echo "Using default duration of 120s"
	DURATION="$DEFAULT_DURATION"
fi

find_cpu_and_mem_field

echo "CPU field is $CPU_FIELD; MEM field is: $MEM_FIELD"
# Create directory and file
if [ ! -d "$DIRPATH/data" ]; then
	mkdir -p "$DIRPATH/data"
fi
DIRPATH="$DIRPATH/data"
FILE="$DIRPATH/$FILENAME"
touch $FILE

echo "writing to file: $FILE"

# Take measurements of cpu and memory
while [ $((COUNTER)) -lt $((DURATION)) ]; do
	DATE=`date +"%H:%M:%S:%s%:z"`
	CPU_USAGE=$(top -b -n 1 | grep -w node | tr -s ' ' | cut -d ' ' -f $CPU_FIELD | paste -sd ',' | sed 's/^/cpu=/; s/,/,cpu=/g')
	MEMORY_USAGE=$(top -b -n 1 | grep -w node | tr -s ' ' | cut -d ' ' -f $MEM_FIELD | paste -sd ',' | sed 's/^/mem=/; s/,/,mem=/g') 
	echo "$DATE,$CPU_USAGE,$MEMORY_USAGE" | tee -a $FILE
	COUNTER=$((COUNTER +1))
	sleep 1
done
