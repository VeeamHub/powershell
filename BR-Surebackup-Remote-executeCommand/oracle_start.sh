###/veeam/oracle_start.sh###
#!/bin/bash
su - oracle << EOF
sqlplus "/as sysdba" << SQL
startup;
exit
SQL
lsnrctl start
EOF
