# mcQueryTester
### An Oracle SQL Stress Test Tool
The mcQueryTester is an simple java application created by Maicon Carneiro (dibiei.blog) to run the same SQL statement many times using parallel connections in Oracle Database.

## Get started
#### 0) Download the tool from dibiei.blog repository:
``` shell
mkdir ~/mcQueryTester
cd  ~/mcQueryTester
wget "https://github.com/maiconcarneiro/blog-dibiei/blob/main/mcQueryTester.jar"
```

#### 1) Create a script file with SQL to be executed
###### Example: sql/insertMyTable.sql
``` sql
INSERT INTO usr_test.my_table (
    id, column1, column2, column3, column4, column5, column6, column7, column8, column9, column10
) VALUES (
    usr_test.my_table_seq.NEXTVAL, :1, :2, :3, :4, :5, :6, :7, :8, :9, RPAD('X', 4000, 'X')
```

#### 2) Create a file with bind variables mapping (:var=value)
###### Example: sql/insertMyTable.bind
``` sql
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

#### 3) Create a configuration file
###### Example: inserts.cfg
``` shell
db.url=cluster01-scan.dibiei.com:1521/racdb_short.dibiei.com
db.user=usr_test
db.pass=oracle
sql.query=sql/insertMyTable.sql
sql.binds=sql/insertMyTable.bind
```

#### 4) Execute the he mcQueryTester using configuration file inserts.cfg
###### NOTE: In this examples, the SQL will be executed 32.000 times (32 conn x 1000 execs)

```
java -jar mcQueryTester.jar --numConnections=32 --numExecs=1000 --config=inserts.cfg
```
