#!/bin/bash
# lsnr_miner.sh - v1.6
# Script to analyze Oracle Listener log file by applying advanced filters and provide connection count at different levels.
#
# Author: Maicon Carneiro (dibiei.blog)
#
# Date       | Author             | Change
# ----------- -------------------- -----------------------------------------------------------
# 20/02/2024 | Maicon Carneiro    | v1 based on the script "lsnr_clients.sh"
# 21/02/2024 | Maicon Carneiro    | Support to Timestamp filter
# 22/02/2024 | Maicon Carneiro    | Support to save_filter and CSV improvements

SUPPORTED_FILE_CHARACTERS='^[a-zA-Z0-9_.-]+$'
SUPPORTED_ATTR="IP|HOST|PROGRAM|USER|SERVICE_NAME"
SUPPORTED_TIMESTAMP_FORMAT="'DD-MON-YYYY' | 'DD-MON-YYYY HH' | 'DD-MON-YYYY HH:MI' | 'DD-MON-YYYY HH:MI:SS'"
LogFileName=""
resultFormat="Table"
CSV_DELIMITER=","
dtLog=$(date +'%Y%m%d_%H%M%S')

filter_attr=""
filter_value=""
filter_file=""
tag="output"
group_by="TIMESTAMP"
group_format="DD-MON-YYYY HH:MI"
BEGIN_TIMESTAMP=""
END_TIMESTAMP=""
SAVE_FILTER_FILE=""

FILE_DATE=$(date +'%H%M%S')
CONNECTIONS_FILE="lsminer.$FILE_DATE.conn.txt"
FILE_LIST_ITEM="lsminer.$FILE_DATE.list.txt"
COUNT_HELPER_FILE="lsminer.$FILE_DATE.cont.txt"
COUNT_HELPER_FILE_STAGE="lsminer.$FILE_DATE.cont_stage.txt"


_printLine(){
  if [ ! -z "$1" ]; then
   for ((i=1; i<=100; i++)); do
    LINE_HELPER+="$1"
   done;
   echo $LINE_HELPER
   unset LINE_HELPER
  fi
}

# Message log helper
printMessage(){
 MSG_TYPE=$1
 MSG_TEXT=$2
 MSG_DATE=$(date +'%d/%m/%Y %H:%M:%S')
 _printLine $3
 echo "$MSG_DATE | $MSG_TYPE | $MSG_TEXT"
 _printLine $3
}

show_help() {
    echo "
      Usage: $0 -log <listener_log_file_name>
                   [-filter <ATTR=VALUE> | ATTR1=VALUE1,ATTR2=VALUE2,ATTRn=VALUEn]
                   [-filter_file <filer_file_name> -file_attr <$SUPPORTED_ATTR>]
                   [-begin 'DD-MON-YYYY HH:MI:SS' -end 'DD-MON-YYYY HH:MI:SS']
                   [-group_by <$SUPPORTED_ATTR>]
                   [-group_format <$SUPPORTED_TIMESTAMP_FORMAT>]
                   [-csv <result_file.csv>]
                      [-csv_delimiter '<csv_character_delimiter>']
                   [-salve_filter <name_new_logfile_filtered> ]
     
      Where: 
       -log           -> Provide an valid LISTENER log file (Required)
       
       -filter        -> Multiple filters with any supported attribute ($SUPPORTED_ATTR)
                          Example: user=zabbix,ip=192.168.1.80,service_name=svcprod.domain.com

       -begin         -> The begin timestamp to filter Listener log file using interval date and time (required with -end)
       -end           -> The end timestamp  to filter Listener log file using interval date and time (required with -begin)
                          Example: -begin '19-AUG-2023 11:00:00' -end '19-AUG-2023 12:00:00'

       -filter_file   -> Provide an helper file to apply filter in batch mode
       -filter_attr   -> Define the supported content type in -filter_file ($SUPPORTED_ATTR)
                          Example: -filter_file appserver_ip_list.txt -filter_attr IP
        
       -save_filter   -> Create a new Log File with only lines filtered by this session.
                         Optionally use this option to reuse the new log file many times with pre-applied commom filters for performance improvement.

       -group_by      -> Specify the ATTR used as Group By for the connections count ($SUPPORTED_ATTR).
                         Default is TIMESTAMP

       -group_format  -> Specify the timestamp format used when -group_by is TIMESTAMP (default). 
                           The default format is DD-MON-YYYY HH:MI (connections per min).
       
       -csv           -> The result will be saved in CSV file instead of print table in the screen.
                         Optionally, provide a custom name for the CSV result file.
                         
       -csv_delimiter -> Allow specify an custom TAG to be used in the CSV result file name.
       
      "
    exit 1
}

################################################## Params ######################################################

if [ $# -lt 2 ]; then
    show_help
fi

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -log)
            LogFileName="$2"
            shift
            shift
            ;;
        -filter)
            filter="$2"
            shift
            shift
            ;;
        -filter_attr)
            filter_attr="${2^^}"
            shift
            shift
            ;;
        -filter_file)
            filter_file="$2"
            shift
            shift
            ;;
        -csv)
           resultFormat="csv"
           if [[ -n "$2" && "$2" != -* ]]; then
             CSV_OUTPUT_FILE="$2"
             shift
            fi
            shift 
            ;;
        -csv_delimiter)
            CSV_DELIMITER="$2"
            shift
            shift
            ;;
        -group_by)
            group_by="${2^^}"
            shift
            shift
            ;;
        -group_format)
            group_format="${2^^}"
            shift
            shift
            ;;
        -begin)
            BEGIN_TIMESTAMP="${2^^}"
            shift
            shift
            ;;
        -end)
            END_TIMESTAMP="${2^^}"
            shift
            shift
            ;;
        -save_filter)
            SAVE_FILTER_FILE="$2"
            shift
            shift
            ;;
        *)
            show_help
            ;;
    esac
done

# check -log
if [ -z "$LogFileName" ]; then
  printMessage "ERROR" "The -log parameter is required." "="
  show_help
elif [ ! -f "$LogFileName"  ]; then
  printMessage "ERROR" "The log file not exists." "="
  show_help
fi

# check -filter_attr
if [ ! -z "$filter_attr" ] && [[ ! "$filter_attr" =~ ^(IP|HOST|SERVICE_NAME|PROGRAM|USER)$ ]]; then
    printMessage "ERROR" "The value for -filter_attr is invalid" "="
    show_help
fi

# check -filter_value
if [ ! -z "$filter_file" ] && [ -z "$filter_attr" ]; then
    printMessage "ERROR" "-filter_attr is required for -filter_file" "="
    show_help
fi

# check -filter_file
if [ ! -z "$filter_file" ] && [ ! -f "$filter_file" ]; then
    printMessage "ERROR" "The file $filter_file provided in -filter_file don't exist." "=" 
    show_help
fi

# check -tag
if [ ! -z "$tag" ] && [[ ! "$tag" =~ $SUPPORTED_FILE_CHARACTERS ]]; then
    printMessage "ERROR" "-tag cannot have special characters." "="
    show_help
fi

# check -group_by
if [ ! -z "$group_by" ] && [[ ! "$group_by" =~ ^(IP|HOST|TIMESTAMP|SERVICE_NAME|USER|PROGRAM)$ ]]; then
    printMessage "ERROR" "Invalid value to -group_by parameter." "="
    show_help
fi

# check -group_format
if [ ! -z "$group_format"  ]; then
 if [ "$group_by" == "TIMESTAMP" ] && [[ ! "$group_format" =~ ^(DD-MON-YYYY|DD-MON-YYYY HH|DD-MON-YYYY HH:MI|DD-MON-YYYY HH:MI:SS)$ ]]; then
    printMessage "ERROR" "The format provided for -group_format is invalid." "="
    show_help
 fi
fi

# check -save_filter
if [ ! -z "$SAVE_FILTER_FILE" ] && [[ ! "$SAVE_FILTER_FILE" =~ $SUPPORTED_FILE_CHARACTERS ]]; then
    printMessage "ERROR" "-save_filter cannot have special characters." "="
    show_help
elif [ -f "$SAVE_FILTER_FILE" ]; then
    printMessage "ERROR" "The file name provided in -save_filter already exists." "="
    show_help
fi

# check -csv
if [ ! -z "$CSV_OUTPUT_FILE" ] && [[ ! "$CSV_OUTPUT_FILE" =~ $SUPPORTED_FILE_CHARACTERS ]]; then
    printMessage "ERROR" "-csv file name cannot have special characters." "="
    show_help
elif [ -f "$CSV_OUTPUT_FILE" ]; then
    printMessage "ERROR" "The file name provided in -csv already exists." "="
    show_help
fi

# check -csv_delimiter
if [ -z "$CSV_DELIMITER"  ]; then
 CSV_DELIMITER=","
fi

#################################################################################################################


if [ "$resultFormat" = "csv" ] && [ -z "$CSV_OUTPUT_FILE" ]; then
 CSV_OUTPUT_FILE="result_${tag}_${dtLog}.csv"
fi

clearTempFiles()
{
   rm -f $CONNECTIONS_FILE
   rm -f $FILE_LIST_ITEM
   rm -f $COUNT_HELPER_FILE
   rm -f $COUNT_HELPER_FILE_STAGE
   rm -rf $FILE_LIST_ITEM.uniq
}

exitHelper(){
  clearTempFiles
  printMessage "$1" "$2"
  echo ""
  echo ""
  exit 1
}


AWK_1=1
FILTER_PREFIX=""
GROUPBY_INFO_SUMMARY="Log Timestamp"

case "$group_by" in
    "TIMESTAMP")
        GROUPBY_INFO_SUMMARY="Log Timestamp"
        ;;
    "HOST")
        GROUPBY_INFO_SUMMARY="Hostname"
        AWK_1=2
        FILTER_PREFIX="HOST="
        ;;
    "SERVICE_NAME")
        GROUPBY_INFO_SUMMARY="SERVICE_NAME"
        AWK_1=2
        FILTER_PREFIX="SERVICE_NAME="
        ;;
    "PROGRAM")
        GROUPBY_INFO_SUMMARY="Program Name"
        AWK_1=2
        FILTER_PREFIX="PROGRAM="
        ;;
    "USER")
        GROUPBY_INFO_SUMMARY="OS USER"
        AWK_1=2
        FILTER_PREFIX="USER="
        ;;
    "IP")
        GROUPBY_INFO_SUMMARY="IP Address"
        AWK_1=3
        FILTER_PREFIX="HOST="
        ;;
    *)
        ;;
esac

applyIntervalFilter(){
start_date="$1"
end_date="$2"

# convert the date to UNIX timestamp format
_start_timestamp=$(date -d "$start_date" "+%Y%m%d%H%M%S")
_end_timestamp=$(date -d "$end_date" "+%Y%m%d%H%M%S")

# input is an listener log file and output is an new file created with lines filtered by timestamp
input_file=$3
output_file=$input_file.timestamp.filter

# return lines that is between start and end timestamp
awk -v start="$_start_timestamp" -v end="$_end_timestamp" -F "*"  '{
    # get the first filed in the log file with DD-MON-YYYY HH:MI:SS format
    date_str=$1

    # map month name 'MON' to month number 'MM'
    months["JAN"] = "01"; months["FEB"] = "02"; months["MAR"] = "03"; months["APR"] = "04";
    months["MAY"] = "05"; months["JUN"] = "06"; months["JUL"] = "07"; months["AUG"] = "08";
    months["SEP"] = "09"; months["OCT"] = "10"; months["NOV"] = "11"; months["DEC"] = "12";

    split(date_str, date_parts, /[-: ]/);
    year = date_parts[3];
    month = months[date_parts[2]];
    day = date_parts[1];
    hour = date_parts[4];
    minute = date_parts[5];
    second = date_parts[6];
    log_timestamp=year""month""day""hour""minute""second

    if (log_timestamp >= start && log_timestamp <= end) {
       print
    }
  }' "$input_file" > $output_file

# replace the input  with the output file
cat $output_file > $input_file
rm -f $output_file

# return the number of lines after the filter
LINES_COUNT=$(cat $input_file | wc -l)
echo "$LINES_COUNT"
}

echo ""
echo "===================================== Summary ====================================="
echo "Log File Name........: $LogFileName"
echo "Filter...............: $filter"
echo "Filter file..........: $filter_file"
echo "Filter attr..........: $filter_attr"
echo "Log Timestamp Begin..: $BEGIN_TIMESTAMP"
echo "Log Timestamp End....: $END_TIMESTAMP"
echo "Group By Column......: $group_by"
echo "Result Type..........: $resultFormat"
echo "==================================================================================="
echo ""

echo ""
echo "------------------------------------------------------------------------------------"


# create the connections file with valid lines
printMessage "INFO" "Processing the log file $LogFileName ..."
grep CONNECT_DATA $LogFileName | grep "establish" >> $CONNECTIONS_FILE

## filter file loop
if [ ! -z "$filter_attr" ] && [ ! -z "$filter_file" ]; then
 
 printMessage "INFO" "Reading Filter File: $filter_file"

 while IFS= read -r filter_line; do
    printMessage "INFO" "Including lines where $filter_attr=$filter_line"
    grep "$filter_attr=$filter_line" "$CONNECTIONS_FILE" >> $CONNECTIONS_FILE.filter
 done < "$filter_file"
 
 cat $CONNECTIONS_FILE.filter > $CONNECTIONS_FILE
 rm -f $CONNECTIONS_FILE.filter

 lines=$(cat $CONNECTIONS_FILE | wc -l)
 if [ "$lines" -eq 0 ]; then
  exitHelper "ERROR" "No lines after apply the filter."
 fi

fi

## simple filter loop
if [ ! -z "$filter" ]; then
 IFS=','
 for filter_helper in $filter; do
  attr=$(echo ${filter_helper^^} | awk -F "=" '{print $1}')
  value=$(echo $filter_helper | awk -F "=" '{print $2}')
  
  printMessage "INFO" "Applying filter: $attr=$value"
  
  if [ "$attr" == "IP" ]; then
   attr="HOST"
  fi

  grep "$attr=$value" $CONNECTIONS_FILE > $CONNECTIONS_FILE.filter
  cat $CONNECTIONS_FILE.filter > $CONNECTIONS_FILE
  rm -f $CONNECTIONS_FILE.filter
 done

 lines=$(cat $CONNECTIONS_FILE | wc -l)
 if [ "$lines" -eq 0 ]; then
  exitHelper "ERROR" "No lines after apply the filter."
 fi

fi

# apply timestamp filter, this filter must be the latest because it is CPU bound
if [ ! -z "$BEGIN_TIMESTAMP" ] && [ ! -z "$END_TIMESTAMP" ]; then
 
 printMessage "INFO" "Applying timestamp filter from '$BEGIN_TIMESTAMP' to '$END_TIMESTAMP'"
 
 lines=$(applyIntervalFilter "$BEGIN_TIMESTAMP" "$END_TIMESTAMP" $CONNECTIONS_FILE)
 
 if [ "$lines" -eq 0 ]; then
  exitHelper "ERROR" "No lines in the provided interval."
 fi

fi

# preserve an copy of the filtered file
if [ ! -z "$SAVE_FILTER_FILE" ]; then
 printMessage "INFO" "Creating filtered file as $SAVE_FILTER_FILE"
 cp $CONNECTIONS_FILE $SAVE_FILTER_FILE
fi

GROUP_BY_WIDTH=20
if [ "$group_by" == "TIMESTAMP" ]; then
 GROUP_BY_WIDTH=${#group_format}
fi

if [ "$group_by" == "TIMESTAMP" ]; then
 # list of distinct log timestamp
 cut -c 1-$GROUP_BY_WIDTH $CONNECTIONS_FILE | sort > $FILE_LIST_ITEM
else
 # list of distinct values for GROUP BY and count
 awk -F "*" -v var1="$AWK_1" '{ print $var1 }' $CONNECTIONS_FILE | awk -F "$FILTER_PREFIX" '{print $2}' | awk -F ")" '{print $1}' | sort > $FILE_LIST_ITEM.helper
 sed "s/$FILTER_PREFIX//g"  $FILE_LIST_ITEM.helper | sed '/^$/d' > $FILE_LIST_ITEM
 rm -f $FILE_LIST_ITEM.helper
fi

 cat $FILE_LIST_ITEM | uniq > $FILE_LIST_ITEM.uniq
 while IFS= read -r line; do
  textFilter=$line
  CONN_COUNT=$(grep -wc "$textFilter" $FILE_LIST_ITEM)
  
  # result can be csv or table format
  if [ "$resultFormat" == "csv" ]; then
   echo "$line""$CSV_DELIMITER""$CONN_COUNT" >> $COUNT_HELPER_FILE_STAGE
  else
   printf "%-30s  %-30s\n" "$line" "$CONN_COUNT" >> $COUNT_HELPER_FILE_STAGE
  fi

 done < "$FILE_LIST_ITEM.uniq"


if [ "$group_by" == "TIMESTAMP" ]; then
 # output ordered by timestamp
 sort  $COUNT_HELPER_FILE_STAGE >> $COUNT_HELPER_FILE
else
 # output oreded by connections count
 sort -r -k 2n $COUNT_HELPER_FILE_STAGE >> $COUNT_HELPER_FILE
fi


printMessage "INFO" "Completed"
echo "------------------------------------------------------------------------------------"
echo ""

 if [ "$resultFormat" == "csv" ]; then
  echo "group_by${CSV_DELIMITER}conn_count" > $CSV_OUTPUT_FILE
  cat $COUNT_HELPER_FILE >> $CSV_OUTPUT_FILE
  echo "[INFO] CSV result file: $CSV_OUTPUT_FILE"
 else
  echo ""
  echo "Connections count by $GROUPBY_INFO_SUMMARY:"
  echo "========================================"
  echo "Item                           Count"
  echo "===========================    ========="
   cat $COUNT_HELPER_FILE
  echo "---------------------------    ---------"
  echo "========================================"
 fi

echo ""
clearTempFiles
