#### 1) The script file with SQL to be executed
```
[oracle@rac01 mcQueryTester]$ cat sql/insertMyTable.sql
INSERT INTO usr_test.my_table (
    id, column1, column2, column3, column4, column5, column6, column7, column8, column9, column10
) VALUES (
    usr_test.my_table_seq.NEXTVAL, :1, :2, :3, :4, :5, :6, :7, :8, :9, RPAD('X', 4000, 'X')
```

#### 2) The file with bind variables mapping (:var=value)
```
[oracle@rac01 mcQueryTester]$ cat sql/insertMyTable.bind
:1='Value1'
:2='Value2'
:3='Value3'
:4='Value4'
:5='Value5'
:6='Value6'
:7='Value7'
:8='Value8'
:9='Value9'
```

#### 3) Configuration file example:
```
[oracle@rac01 mcQueryTester]$ cat inserts.cfg
db.url=cluster01-scan.dibiei.com:1521/racdb_short.dibiei.com
db.user=usr_test
db.pass=oracle
sql.query=sql/insertMyTable.sql
sql.binds=sql/insertMyTable.bind
```

#### 4) Runing the mcQueryTester using configuration file inserts.cfg, and opening 32 connections with 1000 executions per connection
###### NOTE: In this examples, the SQL will be executed 32.000 times (32 conn x 1000 execs)
```
java -jar mcQueryTester.jar --numConnections=32 --numExecs=1000 --config=inserts.cfg
```
