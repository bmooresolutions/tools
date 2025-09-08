### This will dump all databases on your host. Good for if you are moving to a new host or cloning for a DEV instance
### BMoore
#!/bin/bash

# MySQL credentials
MYSQL_USER="your_username"
MYSQL_PASSWORD="your_password"
MYSQL_HOST="localhost"

# Backup destination
BACKUP_DIR="/path/to/backup/$(date +%F)"
mkdir -p "$BACKUP_DIR"

# Get list of databases, excluding system ones
databases=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$MYSQL_HOST" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

# Dump each database
for db in $databases; do
    echo "Backing up $db..."
    mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -h"$MYSQL_HOST" --databases "$db" > "$BACKUP_DIR/$db.sql"
done

echo "✅ Backup complete. Files saved in $BACKUP_DIR"
