#!/bin/bash
# Maicon Carneiro - Salvador BA | 27/04/2023.

# 1) add o IP e hostname no /etc/hosts
export IP_ATUAL=$(ip a | grep -A2 "ether" | grep inet | awk '{print $2}' | awk -F "/" '{print $1}')
export HOSTNAME_ATUAL=$(hostname)
echo "$IP_ATUAL $HOSTNAME_ATUAL" >> /etc/hosts

# 2) preinstall
dnf update -y
dnf install -y oraclelinux-developer-release-el8
dnf config-manager --set-enabled ol8_developer
dnf -y install oracle-database-preinstall-23c

# 3) download
curl -L -o oracle-database-free-23c-1.0-1.el8.x86_64.rpm https://download.oracle.com/otn-pub/otn_software/db-free/oracle-database-free-23c-1.0-1.el8.x86_64.rpm

# 4) install 
dnf -y localinstall oracle-database-free-23c-1.0-1.el8.x86_64.rpm

# 5) configure (silent com a senha padrao = oracle)
(echo "oracle"; echo "oracle";) | /etc/init.d/oracle-free-23c configure

# 6) set env
echo 'export ORACLE_SID=FREE' >> /home/oracle/.bash_profile
echo 'export ORACLE_BASE=/opt/oracle' >> /home/oracle/.bash_profile
echo 'export ORACLE_HOME=/opt/oracle/product/23c/dbhomeFree' >> /home/oracle/.bash_profile
echo 'export PATH=$ORACLE_HOME/bin:$PATH' >> /home/oracle/.bash_profile

echo "
FREEPDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP) ( HOST = $(hostname) ) (PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = FREEPDB1)
    )
  )
" >> /opt/oracle/product/23c/dbhomeFree/network/admin/tnsnames.ora

# 7) Cria o esquema de exemplo HR
su - oracle

curl -L -o sample_schemas.zip https://github.com/oracle-samples/db-sample-schemas/archive/refs/tags/v23.1.zip
unzip sample_schemas.zip

sqlplus system/oracle@freepdb1 <<EOF
create user hr identified by oracle quota unlimited on users;
grant DB_DEVELOPER_ROLE to hr;

conn hr/oracle@freepdb1 
@db-sample-schemas-23.1/human_resources/hr_create.sql
@db-sample-schemas-23.1/human_resources/hr_populate.sql
@db-sample-schemas-23.1/human_resources/hr_code.sql

set pages 100
set lines 400
col object_name format a30
col object_type format a20
select object_type, object_name, created, status from user_objects order by 1;
quit;
EOF
