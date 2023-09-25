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
DEFAULT_DURATION="120"
CPU_FIELD=0
MEM_FIELD=0
COUNTER=0
NUM_LINES_WRITTEN_STDOUT=0

is_numeric() {
	[[ "$1" =~ ^[0-9]+$ ]]
}

is_boolean() {
	[[ "$1" =~ ^(true|false)$ ]] 
}

find_cpu_and_mem_field() {
	IFS=" "
	HEADER_STR=$( top -b -n 1 | grep "CPU" | head -1  )
	FIRST_CHAR=$(printf %.1s "$HEADER_STR")
	local COUNTER=1
	
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

set_arguments() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-d|-duration)
				check_and_set_duration $2
				shift 2
				;;
			-v|-verbose)
				check_and_set_verbose $2
				shift 2
				;;
			*)
				echo "Unknown argument: $1"
				exit 1
				;;
		esac
	done

	if [ -z "$DURATION" ];then
		$DURATION=$DEFAULT_DURATION
		echo "Setting duration to default 120s"
	fi

	if [ -z "$VERBOSE" ]; then
		VERBOSE=false
	fi

	if $VERBOSE; then
		echo "Logging option is set to verbose and will continue logging data entries"
	else
		echo "Logging option is set to non-verbose. After logging the first 5 lines it will continue writing to the .csv file silently"
	fi
}

check_and_set_duration() {     
	if is_numeric "$1"; then
		echo "Setting duration to $1s"
        	DURATION="$1"
	else
                echo "Error: Duration argument must be a number."
                exit 1
        fi
}

check_and_set_verbose() {
	if is_boolean "$1"; then
		echo "Setting verbose to $1"
		VERBOSE="$2"
	else 
		echo "Error: Verbose argument must be boolean"
		exit 1
	fi
}

set_arguments "$@"
find_cpu_and_mem_field

# Create directory and file
if [ ! -d "$DIRPATH/data" ]; then
	mkdir -p "$DIRPATH/data"
fi
DIRPATH="$DIRPATH/data"
FILE="$DIRPATH/$FILENAME"
touch $FILE

echo "Writing to file: $FILE"

# Take measurements of cpu and memory
while [ $((COUNTER)) -lt $((DURATION)) ]; do
	DATE=`date +"%H:%M:%S:%s%:z"`
	CPU_USAGE=$(top -b -n 1 | grep -w node | tr -s ' ' | cut -d ' ' -f $CPU_FIELD | paste -sd ',' | sed 's/^/cpu=/; s/,/,cpu=/g')
	MEMORY_USAGE=$(top -b -n 1 | grep -w node | tr -s ' ' | cut -d ' ' -f $MEM_FIELD | paste -sd ',' | sed 's/^/mem=/; s/,/,mem=/g') 
	 
        # should we print also to stdout?
        NUM_LINES_WRITTEN_STDOUT=$[$NUM_LINES_WRITTEN_STDOUT +1]
	if [[ $NUM_LINES_WRITTEN_STDOUT -lt 6 || $VERBOSE = true ]]; then
		echo "Appending line $NUM_LINES_WRITTEN_STDOUT: $(echo "$DATE,$CPU_USAGE,$MEMORY_USAGE" | tee -a $FILE)"
        elif [[ $NUM_LINES_WRITTEN_STDOUT -eq 5 && $VERBOSE = false ]]; then
                echo "[verbose mode is off, logging continues on the output file, not on stdout]"
                echo "$DATE,$CPU_USAGE,$MEMORY_USAGE" >> $FILE
        fi
	
	COUNTER=$((COUNTER +1))
	sleep 1
done

echo "Written $NUM_LINES_WRITTEN to the csv file"
