#!/bin/bash

MASTER_IP="192.168.0.52"
SLAVE_IP="192.168.0.53"
SLAVE_SSH_PASS="kazak1221"
MYSQL_ROOT_PASS="Kazak1221"
REPL_USER="repl_user"
REPL_PASS="Kazak1221!"
DB_NAME="Otus_final"
MYSQL_USER="root"
NEW_PASS="Kazak1221"
apt install -y mysql-server-8.0
mysql -u"$MYSQL_USER" -e "
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '$NEW_PASS';"
function mysql_exec() {
  MYSQL_PWD="$MYSQL_ROOT_PASS" mysql -uroot -e "$1" 2>/dev/null 
}
function ssh_exec() {
  sshpass -p "$SLAVE_SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$SLAVE_IP" "$1" 
}
apt-get install -y sshpass
cat > /etc/mysql/mysql.conf.d/replication.cnf <<EOF
[mysqld]
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = $DB_NAME
bind-address = $MASTER_IP
EOF
systemctl restart mysql
mysql_exec "CREATE USER IF NOT EXISTS '$REPL_USER'@'$SLAVE_IP' IDENTIFIED BY '$REPL_PASS';"
mysql_exec "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'$SLAVE_IP';"
mysql_exec "ALTER USER '$REPL_USER'@'$SLAVE_IP' IDENTIFIED WITH mysql_native_password BY '$REPL_PASS';"
mysql_exec "FLUSH PRIVILEGES;"
mysql_exec "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql_exec "USE $DB_NAME; CREATE TABLE IF NOT EXISTS Otus_final_table ( id INT PRIMARY KEY, value VARCHAR(255) NOT NULL);"
mysql_exec "USE $DB_NAME; INSERT INTO Otus_final_table (id, value) VALUES (1, 'testrow1'),(2, 'testrow2'),(3, 'testrow3');"
mysql_exec "FLUSH TABLES WITH READ LOCK;"
MASTER_STATUS=$(mysql_exec "SHOW MASTER STATUS\G")
LOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
LOG_POS=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')
mysql_exec "UNLOCK TABLES;"
DUMP_FILE="/tmp/replication_dump.sql"
MYSQL_PWD="$MYSQL_ROOT_PASS" mysqldump -uroot $DB_NAME > $DUMP_FILE 
sshpass -p "$SLAVE_SSH_PASS" scp -o StrictHostKeyChecking=no $DUMP_FILE root@$SLAVE_IP:/tmp/
ssh_exec "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server" 
ssh_exec "cat > /etc/mysql/mysql.conf.d/replication.cnf <<EOF
[mysqld]
server-id = 2
relay-log = /var/log/mysql/mysql-relay-bin.log
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = $DB_NAME
read_only = 1
EOF"
ssh_exec "systemctl restart mysql" 
ssh_exec "mysql -uroot -e \"CREATE DATABASE IF NOT EXISTS $DB_NAME;\"" 
ssh_exec "mysql -uroot $DB_NAME < /tmp/replication_dump.sql && rm /tmp/replication_dump.sql" 
ssh_exec "mysql -uroot -e \"STOP SLAVE;\""
ssh_exec "mysql -uroot -e \"CHANGE MASTER TO
  MASTER_HOST='$MASTER_IP',
  MASTER_USER='$REPL_USER',
  MASTER_PASSWORD='$REPL_PASS',
  MASTER_LOG_FILE='$LOG_FILE',
  MASTER_LOG_POS=$LOG_POS;\""
ssh_exec "mysql -uroot -e \"START SLAVE;\"" 


