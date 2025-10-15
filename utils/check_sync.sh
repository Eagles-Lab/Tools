#!/bin/bash
MASTER_POD=$(kubectl get pods -l app=mysql-master -o jsonpath='{.items[0].metadata.name}')
SLAVE_POD=$(kubectl get pods -l app=mysql-slave -o jsonpath='{.items[0].metadata.name}')

# 在主库创建数据库和表
kubectl exec $MASTER_POD -- mysql -uroot -p123456 -e "CREATE DATABASE IF NOT EXISTS app_db;"
kubectl exec $MASTER_POD -- mysql -uroot -p123456 -e "CREATE TABLE IF NOT EXISTS app_db.test_table (id INT, content VARCHAR(255));"

# 在主库写入数据
kubectl exec $MASTER_POD -- mysql -uroot -p123456 -e "INSERT INTO app_db.test_table VALUES (2, 'Auto Test');"

# 在从库检查数据
kubectl exec $SLAVE_POD -- mysql -uroot -p123456 -e "SELECT * FROM app_db.test_table;" | grep "Auto Test"
if [ $? -eq 0 ]; then
    echo "Replication is working!"
else
    echo "Replication failed!"
fi