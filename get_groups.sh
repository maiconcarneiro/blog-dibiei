## script: get_groups.sh v1.3
## syntax: "./get_groups.sh" or  "./get_groups.sh <ORACLE_HOME_PATH>" or "./get_groups.sh all"
##  ./get_groups.sh use the current $ORACLE_HOME as default path.
##
## Example:
#   $ ./get_groups.sh
#   OSDBA=oinstall,OSOPER=oinstall,OSASM=oinstall,OSBACKUP=oinstall,OSDG=oinstall,OSKM=oinstall,OSRAC=oinstall
#
## Maicon Carneiro - dibiei.blog
## 11/01/2024 - v1.0 with FPP format standard
## 27/01/2024 - v1.1 support for multiple Oracle Home reading /etc/oratab
## 29/01/2024 - v1.2 support for OUI (Oracle Universal Installer) format


# 1) Execution without parameter use the current ORACLE_HOME
# 2) Execution with the PATH provided by user get the groups for the specified ORACLE_HOME
# 3) Execution with option "all" get the groups for all ORACLE_HOME listed in /etc/oratab file.
USER_OPTION=""

# Default format of the output (FPP or OUI)
#  FPP = Fleet Patching and Provisioning
#  OUI = Oracle Universal Installer
RESULT_TYPE="FPP"

# show script help usage
show_help() {
    echo "Uso: $0 [-home <Oracle Home Path>] [-oui]"
    echo "  -home    : Oracle Home Path. Example: /u01/app/oracle/product/19.0.0/dbhome_1"
    echo "  -oui     : Get the result with OUI format instead of FPP format"
    exit 1
}

# check parameters
while [[ $# -gt 0 ]]; do
    case $1 in
        -home)
            shift
            if [[ $# -eq 0 || $1 == -* ]]; then
                show_help
            fi
            USER_OPTION=$1
            ;;
        -oui)
            RESULT_TYPE="OUI"
            ;;
        *)
            show_help
            ;;
    esac
    shift
done



addGroupValueFPP()
{
  GRP_NAME=$1
  GRP_VALUE=$2
  if [ -z $GRP_LIST_FPP ]; then
   GRP_LIST_FPP="$GRP_NAME=$GRP_VALUE"
  else
   GRP_LIST_FPP="${GRP_LIST_FPP},$GRP_NAME=$GRP_VALUE"
  fi
}

addGroupValueOUI()
{
  GROUP_NAME=$1
  GROUP_VALUE=$2
  GROUP_OUI=$GROUP_NAME

  if [ "$BINARY_TYPE" == "GRID" ]; then
   OUI_LINE="oracle.install.asm.${GROUP_OUI}=$GROUP_VALUE"
  else 
   
    if [ "$GROUP_NAME" != "OSDBA" ] && [ "$GROUP_NAME" != "OSOPER" ]; then
      GROUP_OUI="${GROUP_NAME}DBA"
    fi
    OUI_LINE="oracle.install.db.$GROUP_OUI"_GROUP="$GROUP_VALUE"
  fi

  GRP_LIST_OUI+=($OUI_LINE)
}


runGetGroups(){

# Default Binary type (RDBMS or GRID)
BINARY_TYPE="RDBMS"

# YES for Fleet Patching and Provisioning (FPP) standard
FORCE_OSPER_GRP="YES"


if [ ! -z "$2" ]; then
 LIST_TYPE=$2
fi

# set the source Oracle Home
SOURCE_ORACLE_HOME=""
OH_PARAM=$1

if [ ! -z "$OH_PARAM" ]; then
 SOURCE_ORACLE_HOME=$OH_PARAM
 elif [ ! -z $ORACLE_HOME ]; then
  SOURCE_ORACLE_HOME=$ORACLE_HOME
 else
  echo "ORACLE_HOME is required."
  exit 1
fi

# check if the ORACLE_HOME exists
if [ ! -f "$SOURCE_ORACLE_HOME/rdbms/lib/config.c" ]; then
 echo "Invalid ORACLE_HOME: $SOURCE_ORACLE_HOME"
 exit 1
fi

# check binary type
if [ -f "$SOURCE_ORACLE_HOME/crs/install/rootcrs.sh" ]; then
 BINARY_TYPE="GRID"
fi

# function to read the "config.c" file and return the group value to the specific group name.
addGroupValue(){
 GRP_DEFINE=$1
 GRP_NAME=$2
 GRP_FORCE=$3
 GRP_VALUE=$(grep "#define $GRP_DEFINE" $SOURCE_ORACLE_HOME/rdbms/lib/config.c | awk -F '"' '{print $2}')

 if [[ ! -z "$GRP_VALUE" || $GRP_FORCE == "YES" ]]; then
  
  if [ "$RESULT_TYPE" == "FPP" ]; then
   addGroupValueFPP $GRP_NAME $GRP_VALUE
  else
   addGroupValueOUI $GRP_NAME $GRP_VALUE
  fi

 fi
}


# get all possible OS Groups value
GRP_LIST_FPP=""
GRP_LIST_OUI=()
addGroupValue "SS_DBA_GRP" "OSDBA"
addGroupValue "SS_OPER_GRP" "OSOPER" "$FORCE_OSPER_GRP"

# these groups are specific to RDBMS binary
if [ "$BINARY_TYPE" == "RDBMS" ]; then
 addGroupValue "SS_DGD_GRP"  "OSDG"
 addGroupValue "SS_KMT_GRP"  "OSKM"
 addGroupValue "SS_RAC_GRP"  "OSRAC"
 addGroupValue "SS_BKP_GRP"  "OSBACKUP"
fi;

addGroupValue "SS_ASM_GRP"  "OSASM"


if [ "$RESULT_TYPE" == "FPP" ]; then
  echo "$GRP_LIST_FPP"
 else
  for OUI_GROUP in "${GRP_LIST_OUI[@]}"; do
    echo "$OUI_GROUP"
  done
fi


}



# call the runGetGroups function based on the USER Option
if [ "$USER_OPTION" == "all" ]; then
 echo ""
 for OH_PATH in $(grep -v "^#" /etc/oratab | awk -F ":" '{print $2}' | sort -u | grep "^/"); do
  echo "Oracle Home: $OH_PATH"
  echo "$(runGetGroups $OH_PATH)"
  echo ""
 done
else
 runGetGroups "$USER_OPTION"
fi;
