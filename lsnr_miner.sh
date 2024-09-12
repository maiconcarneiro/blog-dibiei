#!/bin/bash
# lsnr_miner.sh - v1.13
# Script to analyze Oracle Listener log file by applying advanced filters and provide connection count at different levels.
#
# https://raw.githubusercontent.com/maiconcarneiro/blog-dibiei/main/lsnr_miner.sh
# 
# Author: Maicon Carneiro (dibiei.blog)
#
# Date       | Author             | Change
# ----------- -------------------- ------------------------------------------------------------------------
# 20/02/2024 | Maicon Carneiro    | v1 based on the script "lsnr_clients.sh"
# 21/02/2024 | Maicon Carneiro    | Support to Timestamp filter
# 22/02/2024 | Maicon Carneiro    | Support to save_filter and CSV improvements
# 23/02/2024 | Maicon Carneiro    | Support for Filter using IP and dynamic column width in the result table 
# 29/02/2024 | Maicon Carneiro    | Support multiple log files passing an directory in -log parameter
# 12/09/2024 | Maicon Carneiro    | Support for values with "\" bar during counting 

FILE_DATE=$(date +'%H%M%S')
CURRENT_DIR=$(pwd)
HELPER_FILE_PREFIX="${CURRENT_DIR}/lsminer.$FILE_DATE"

CONNECTIONS_FILE="${HELPER_FILE_PREFIX}.conn.txt"
FILE_LIST_ITEM="${HELPER_FILE_PREFIX}.list.txt"
COUNT_HELPER_FILE="${HELPER_FILE_PREFIX}.cont.txt"
COUNT_HELPER_FILE_STAGE="${HELPER_FILE_PREFIX}.cont_stage.txt"
SOURCE_HOSTNAME_FILE="${HELPER_FILE_PREFIX}.sourcehost.txt"
LISTENER_LOG_FILES="${HELPER_FILE_PREFIX}.listener_log_files.txt"

LOG_PATH=""
LOG_TYPE=""
LogFileName=""
filter_attr=""
filter_value=""
filter_file=""
group_by="TIMESTAMP"
group_format="DD-MON-YYYY HH:MI"
BEGIN_TIMESTAMP=""
END_TIMESTAMP=""
SAVE_FILTER_FILE=""
resultFormat="Table"
CSV_DELIMITER=","
FILTER_ONLY=""

SUPPORTED_FILE_CHARACTERS='^[a-zA-Z0-9_.-]+$'
SUPPORTED_ATTR="IP|HOST|PROGRAM|USER|SERVICE_NAME"
SUPPORTED_TIMESTAMP_FORMAT="'DD-MON-YYYY' | 'DD-MON-YYYY HH' | 'DD-MON-YYYY HH:MI' | 'DD-MON-YYYY HH:MI:SS'"


# used by printMessage and the result with table format.
_printLine(){
 if [ ! -z "$1" ]; then
   MAX_LENGTH=$2
   if [ -z "$MAX_LENGTH" ]; then
     MAX_LENGTH=100
   fi
   for ((i=1; i<=$MAX_LENGTH; i++)); do
    LINE_HELPER+="$1"
   done;
   echo $LINE_HELPER
   unset LINE_HELPER
 fi
}

# Message log helper
printMessage(){
 MSG_TYPE=$(printf "%-7s" "$1")
 MSG_TEXT=$2
 MSG_DATE=$(date +'%d/%m/%Y %H:%M:%S')
 _printLine $3
 echo "$MSG_DATE | $MSG_TYPE | $MSG_TEXT"
 _printLine $3
}

show_help() {
    echo "
      Usage: $0 -log <listener_log_path>
                   [-filter <ATTR=VALUE> | ATTR1=VALUE1,ATTR2=VALUE2,ATTRn=VALUEn]
                   [-filter_file <filer_file_name> -file_attr <$SUPPORTED_ATTR>]
                   [-begin 'DD-MON-YYYY HH:MI:SS' -end 'DD-MON-YYYY HH:MI:SS']
                   [-group_by <$SUPPORTED_ATTR>]
                   [-group_format <$SUPPORTED_TIMESTAMP_FORMAT>]
                   [-csv <result_file.csv>] [-csv_delimiter '<csv_char_delimiter>']
                   [-salve_filter <name_new_logfile_filtered> ]
                   [-filter_only <name_new_logfile_filtered> ]
     
      Where: 
       -log           -> Provide an valid LISTENER log file or Path with multiple log files (Required)
       
       -filter        -> Multiple filters with any supported attribute ($SUPPORTED_ATTR)
                          Example: user=zabbix,ip=192.168.1.80,service_name=svcprod.domain.com

       -begin         -> The BEGIN and END timestamp to filter Listener log file using date interval.
       -end               Example: -begin '19-AUG-2023 11:00:00' -end '19-AUG-2023 12:00:00'

       -filter_file   -> Provide an helper file to apply filter in batch mode
       -filter_attr   -> Define the supported content type in -filter_file ($SUPPORTED_ATTR)
                          Example: -filter_file appserver_ip_list.txt -filter_attr IP
        
       -save_filter   -> Create a new Log File with only lines filtered by this session.
       -filter_only   -> similar to -save_filter, but no count connections will be perfomed.
                         Optionally use this option to reuse the new log file many times with pre-applied commom filters for performance improvement.

       -group_by      -> Specify the ATTR used as Group By for the connections count ($SUPPORTED_ATTR).
                         Default is TIMESTAMP

       -group_format  -> Specify the timestamp format used when -group_by is TIMESTAMP (default). 
                           The default format is DD-MON-YYYY HH:MI (connections per min).
       
       -csv           -> The result will be saved in CSV file instead of print table in the screen.
                         Optionally, provide a custom name for the CSV result file.
                         
       -csv_delimiter -> Allow specify an custom CSV delimiter (default is ',').
       
      "
    exit 1
}

################################################## Params Begin ######################################################

if [ $# -lt 2 ]; then
    show_help
fi

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -log)
            LOG_PATH="$2"
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
            SAVE_FILTER_FILE="save_filter_$FILE_DATE.log"
            if [[ -n "$2" && "$2" != -* ]]; then
             SAVE_FILTER_FILE="$2"
             shift
            fi
            shift 
            ;;
        -filter_only)
            FILTER_ONLY="YES"
            SAVE_FILTER_FILE="save_filter_$FILE_DATE.log"
            if [[ -n "$2" && "$2" != -* ]]; then
             SAVE_FILTER_FILE="$2"
             shift
            fi
            shift 
            ;;
        *)
            show_help
            ;;
    esac
done

# check -log
if [ -z "$LOG_PATH" ]; then
  printMessage "ERROR" "The -log parameter is required." "="
  show_help
fi

if [ -f "$LOG_PATH" ]; then
 LOG_TYPE="FILE"
elif [ -d "$LOG_PATH" ]; then
 LOG_TYPE="DIR"
else
 printMessage "ERROR" "The log file path not exists." "="
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

if [ "$resultFormat" = "csv" ] && [ -z "$CSV_OUTPUT_FILE" ]; then
 CSV_OUTPUT_FILE="result_${FILE_DATE}.csv"
fi

################################################ Params End #################################################

clearTempFiles()
{
   rm -f $CONNECTIONS_FILE
   rm -f $FILE_LIST_ITEM
   rm -f $COUNT_HELPER_FILE
   rm -f $COUNT_HELPER_FILE_STAGE
   rm -f $FILE_LIST_ITEM.uniq
   rm -f $SOURCE_HOSTNAME_FILE
   rm -f $LISTENER_LOG_FILES
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


# used to apply timestamp filter after consolidate the logfile
applyIntervalFilter(){
start_date="$1"
end_date="$2"

_start_timestamp=$(date -d "$start_date" "+%Y%m%d%H%M%S")
_end_timestamp=$(date -d "$end_date" "+%Y%m%d%H%M%S")

input_file=$3
output_file=$input_file.timestamp.filter

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

cat $output_file > $input_file
rm -f $output_file

LINES_COUNT=$(cat $input_file | wc -l)
echo "$LINES_COUNT"
}



listDirLogFiles(){

  touch $LISTENER_LOG_FILES
  for FILE in $(grep -s -l -m 1 "CONNECT_DATA" *.log); do
   BEGIN_LOG=$(grep -m 1 "CONNECT_DATA" $FILE | awk -F "*" '{print $1}' | cut -c 1-20 )
   END_LOG=$(tail -1 $FILE | awk -F "*" '{print $1}' | cut -c 1-20 )
   echo "$FILE*$BEGIN_LOG*$END_LOG*" >> $LISTENER_LOG_FILES
  done
  
  # define interval from '1970-01-01' to current date if timestamp filter was not used.
  if [ -z "$BEGIN_TIMESTAMP" ]; then
  _start_timestamp=$(date -d "1970-01-01" +'%Y%m%d%H%M%S')
  _end_timestamp=$(date +'%Y%m%d%H%M%S')
  else
  _start_timestamp=$(date -d "$BEGIN_TIMESTAMP" "+%Y%m%d%H%M%S")
  _end_timestamp=$(date -d "$END_TIMESTAMP" "+%Y%m%d%H%M%S")
  fi
  
  awk -v start="$_start_timestamp" -v end="$_end_timestamp" -F "*"  '{
      # get the first filed in the log file with DD-MON-YYYY HH:MI:SS format
      date_str1=$2
      date_str2=$3

      # map month name 'MON' to month number 'MM'
      months["JAN"] = "01"; months["FEB"] = "02"; months["MAR"] = "03"; months["APR"] = "04";
      months["MAY"] = "05"; months["JUN"] = "06"; months["JUL"] = "07"; months["AUG"] = "08";
      months["SEP"] = "09"; months["OCT"] = "10"; months["NOV"] = "11"; months["DEC"] = "12";
      
      # begin log timestamp
      split(date_str1, date_parts1, /[-: ]/);
      year1 = date_parts1[3];
      month1 = months[date_parts1[2]];
      day1 = date_parts1[1];
      hour1 = date_parts1[4];
      minute1 = date_parts1[5];
      second1 = date_parts1[6];
      log_begin=year1""month1""day1""hour1""minute1""second1
      
      # end log timestamp
      split(date_str2, date_parts2, /[-: ]/);
      year2 = date_parts2[3];
      month2 = months[date_parts2[2]];
      day2 = date_parts2[1];
      hour2 = date_parts2[4];
      minute2 = date_parts2[5];
      second2 = date_parts2[6];
      log_end=year2""month2""day2""hour2""minute2""second2

      if ( (start >= log_begin && start <= log_end) || 
           (end >= log_begin && end <= log_end)     || 
           (log_begin >= start && log_begin <= end) || 
           (log_end >= start && log_end <= end) ) {
       print log_begin";"$1
      }
    }' "$LISTENER_LOG_FILES" | sort -t';' -n -k1 > $LISTENER_LOG_FILES.tmp
  
  rm -f $LISTENER_LOG_FILES
  touch $LISTENER_LOG_FILES
  for FILE in $(cat $LISTENER_LOG_FILES.tmp | awk -F ";" '{print $2}'); do
   CHECK_LOG=$(grep -c $FILE $LISTENER_LOG_FILES)
   if [ "$CHECK_LOG" -eq 0 ]; then
    echo "$FILE" >> $LISTENER_LOG_FILES
   fi
  done

  rm -f $LISTENER_LOG_FILES.tmp
  COUNT=$(cat $LISTENER_LOG_FILES | wc -l)
  echo "$COUNT"
}


# get the source hostnames
listSourceHosts(){
FILE_NAME="$1"
grep "status" $FILE_NAME | awk -F "HOST=" '{print $2}' | awk -F ")" '{print $1}' | awk -F "." '{print $1}' | sort -u > $SOURCE_HOSTNAME_FILE
}

printSourceHosts(){
LIST_HOST_NAMES=""
for NAME in $(cat $SOURCE_HOSTNAME_FILE | sort -u); do
 if [ -z "$LIST_HOST_NAMES" ]; then
  LIST_HOST_NAMES="$NAME"
 else
  LIST_HOST_NAMES="$LIST_HOST_NAMES,$NAME"
 fi
done
printMessage "INFO" "DB Server: $LIST_HOST_NAMES"
}

prepareLogFile(){
 LogFileName="$1"
  printMessage "INFO" "Processing the log file $LogFileName"
  listSourceHosts $LogFileName
  grep CONNECT_DATA $LogFileName | grep "establish" >> $CONNECTIONS_FILE
}


#######################################################################
######################### BEGIN EXECUTION #############################
#######################################################################

echo ""
echo "============================================= Summary =================================================="
echo "Log Path.............: $LOG_PATH"
echo "Log Type.............: $LOG_TYPE"
echo "Filter...............: $filter"
echo "Filter file..........: $filter_file"
echo "Filter attr..........: $filter_attr"
echo "Save Filter..........:"
echo "Log Timestamp Begin..: $BEGIN_TIMESTAMP"
echo "Log Timestamp End....: $END_TIMESTAMP"
echo "Group By Column......: $group_by"
echo "Result Type..........: $resultFormat"
echo "=========================================================================================================="
echo ""

echo ""
echo "----------------------------------------------------------------------------------------------------------"

# create the connections file with valid lines
if [ "$LOG_TYPE" == "FILE" ]; then
 prepareLogFile $LOG_PATH
else 
 
 cd $LOG_PATH
 LINES_COUNT=$(listDirLogFiles)
 if [ "$LINES_COUNT" -gt 0 ]; then
  for FILE in $(cat $LISTENER_LOG_FILES); do
   prepareLogFile $FILE
  done
  printSourceHosts
 else
  exitHelper "WARNING" "Log files not found." 
 fi

 cd $CURRENT_DIR
fi

printMessage "INFO" "Checking filters"

## filter file loop
if [ ! -z "$filter_attr" ] && [ ! -z "$filter_file" ]; then
 
 printMessage "INFO" "Reading Filter File: $filter_file"
 
 # print filter as 'IP='' but apply grep as 'HOST=''
 _local_filter_attr=$filter_attr
 if [ "$filter_attr" == "IP" ]; then
  _local_filter_attr="HOST"
 fi

 while IFS= read -r filter_line; do
    printMessage "INFO" "Including lines where $filter_attr=$filter_line"
    grep "'$_local_filter_attr=$filter_line'" "$CONNECTIONS_FILE" >> $CONNECTIONS_FILE.filter
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

  grep "'$attr=$value'" $CONNECTIONS_FILE > $CONNECTIONS_FILE.filter
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

if [ "$FILTER_ONLY" == "YES" ]; then
  exitHelper "INFO" "Completed"
fi


printMessage "INFO" "Preparing to count..."

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

 printMessage "INFO" "Counting connections..."
 cat $FILE_LIST_ITEM | uniq > $FILE_LIST_ITEM.uniq
 while IFS= read -r line; do
  textFilter=$line
  textFilterEscaped=$(echo "$textFilter" | sed 's/\\/\\\\/g')
  CONN_COUNT=$(grep -wc "$textFilterEscaped" $FILE_LIST_ITEM)


  if [ ${#line} -gt "$GROUP_BY_WIDTH" ]; then
   GROUP_BY_WIDTH=$(( ${#line} + 10 ))
  fi

  # result can be csv or table format
  if [ "$resultFormat" == "csv" ]; then
   echo "$line""$CSV_DELIMITER""$CONN_COUNT" >> $COUNT_HELPER_FILE_STAGE
  else
   echo "$line | $CONN_COUNT" >> $COUNT_HELPER_FILE_STAGE
  fi

 done < "$FILE_LIST_ITEM.uniq"


if [ "$group_by" == "TIMESTAMP" ]; then
 # output ordered by timestamp
 sort  $COUNT_HELPER_FILE_STAGE >> $COUNT_HELPER_FILE
else
 # output oreded by connections count
 sort -t '|' -r -k 2n $COUNT_HELPER_FILE_STAGE >> $COUNT_HELPER_FILE
fi


printMessage "INFO" "Completed"
echo "----------------------------------------------------------------------------------------------------------"
echo ""


 if [ "$resultFormat" == "csv" ]; then
  echo "group_by${CSV_DELIMITER}conn_count" > $CSV_OUTPUT_FILE
  cat $COUNT_HELPER_FILE >> $CSV_OUTPUT_FILE
  echo "[INFO] CSV result file: $CSV_OUTPUT_FILE"
 else
  LINE_SIZE=$((GROUP_BY_WIDTH + 10))
  echo ""
  echo "Connections count by $GROUPBY_INFO_SUMMARY:"
  _printLine "=" $LINE_SIZE
  echo "Item Count" | awk -v width="$GROUP_BY_WIDTH" '{ printf "%-" width "s%s\n", $1, $2 }'
  _printLine "=" $LINE_SIZE
   awk -F "|" -v width="$GROUP_BY_WIDTH" '{ printf "%-" width "s%s\n", $1, $2 }' $COUNT_HELPER_FILE
  _printLine "=" $LINE_SIZE
  echo ""
 fi

echo ""
clearTempFiles
