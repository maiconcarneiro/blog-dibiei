#!/bin/bash
# Script: oop_listener_helper.sh
# Maicon Carneiro (dibiei.blog)
#
### Examples:
# Move listener between Oracle Homes and update static service in listener.ora of DB Home:
#  ./oop_listener_helper.sh -sourcehome /u01/app/oracle/product/19.0.0/DB1922 -desthome /u01/app/oracle/product/19.0.0/DB1921 -move
#
# update static service in listener.ora of Grid Home and reload the listener, without move them:
#  ./oop_listener_helper.sh \
#    -sourcehome /u01/app/oracle/product/19.22.0.0/dbhome_1 \
#    -desthome /u01/app/oracle/product/19.25.0.0/dbhome_1 \
#    -listener_home /u01/app/19.25.0/grid \
#    -update -reload
#
# Run script as root to modify listener of "grid" user
#  su - grid -c "/tmp/oop_listener_helper.sh -sourcehome <source_dbhome> -desthome <target_dbhome> -listener_home /u01/app/product/19.0.0/GI1922 -update -reload"


BKPHOUR=$(date '+%Y%m%d_%H-%M-%S')
sourcehome=""
desthome=""
copy=false
move=false
update=false
listener_home=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -sourcehome)
            sourcehome="$2"
            shift 2
            ;;
        -desthome)
            desthome="$2"
            shift 2
            ;;
        -listener_home)
            listener_home="$2"
            shift 2
            ;;
        -move)
            move=true
            shift
            ;;
        -copy)
            copy=true
            shift
            ;;
        -update)
            update=true
            shift
            ;;
        -reload)
            reload=true
            shift
            ;;            
        *)
            echo "Invalid param: $1"
            exit 1
            ;;
    esac
done

sourceTNS="$sourcehome/network/admin"

if [ -z "$listener_home" ]; then
  destTNS="$desthome/network/admin"
 else
  destTNS="$listener_home/network/admin"
fi


_copy_file_bkp(){
 FILE=$1
 DEST=$2
 if [ -f "$FILE" ]; then
  cp $FILE $DEST/
 fi
}

create_backup(){
TNS_HOME="$1"
BKP_TMP="TNS_BACKUP_$BKPHOUR"
cd $TNS_HOME
mkdir $BKP_TMP
_copy_file_bkp listener.ora $BKP_TMP
_copy_file_bkp sqlnet.ora $BKP_TMP
_copy_file_bkp tnsnames.ora $BKP_TMP
echo "HOSTNAME=$(hostname -s)" >> $BKP_TMP/info.txt
echo "TNS_ADMIN=$TNS_HOME" >> $BKP_TMP/info.txt
zip -qr $BKP_TMP.zip $BKP_TMP 
rm -rf $BKP_TMP 
echo "Backup created at $TNS_HOME/$BKP_TMP.zip"
}

copy_files(){
    echo "Copying config files from $sourcehome to $desthome"
    cp "$sourceTNS"/*.ora "$destTNS/"
}

update_static_registry() {
    create_backup $destTNS
    echo "Updating file listener.ora in $destTNS with OLD_HOME=$sourcehome and NEW_HOME=$desthome"
    sed -i "s|$sourcehome|$desthome|g" "$destTNS/listener.ora"
}


lsnrctl_helper(){
 ACTION=$1
 export ORACLE_HOME=$2
 LISTENER=$3
 $ORACLE_HOME/bin/lsnrctl $ACTION $LISTENER
}

move_listener(){
 IFS=$'\n'
 for LINE in $(pgrep -f "$sourcehome/bin/tnslsnr" -a); do
  NAME=$( echo $LINE | awk '{print $3}' )
  lsnrctl_helper "stop" $sourcehome $NAME
  lsnrctl_helper "start" $desthome $NAME
 done;
}

reload_listener(){
 IFS=$'\n'
 for LINE in $(pgrep -f "$listener_home/bin/tnslsnr" -a); do
  NAME=$( echo $LINE | awk '{print $3}' )
  echo "Reloading $NAME"
  lsnrctl_helper "reload" $listener_home $NAME
 done;
}

if [ "$copy" = true ]; then
 copy_files
fi

if [ "$update" = true ]; then
 update_static_registry
fi

if [ "$move" = true ]; then
 move_listener
fi

if  [ "$reload" = true ]; then
 reload_listener
fi

echo "Completed."
