#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
        set -- mysqld "$@"
fi

if [ -n "${MYSQL_CLUSTER}" ]; then      
    # the ip of the other node to connect to and don't wait it is offline  
    sed -i "s/wsrep_cluster_address =.*/wsrep_cluster_address = gcomm:\/\/$MYSQL_CLUSTER?pc.wait_prim=no/" /etc/mysql/my.cnf
    sed -i "s/wsrep_sst_auth =.*/wsrep_sst_auth = root:$MYSQL_ROOT_PASSWORD/" /etc/mysql/my.cnf
fi

sed -i "s/.*wsrep_provider_options =.*/wsrep_provider_options = 'gcache.size = 3G'/" /etc/mysql/my.cnf 
 
if [ -n "${MYSQL_innodb_buffer_pool_size}" ]; then
    sed -i "s/.*innodb_buffer_pool_size.*/innodb_buffer_pool_size = $MYSQL_innodb_buffer_pool_size/" /etc/mysql/my.cnf         
fi
if [ -n "${MYSQL_innodb_log_buffer_size}" ]; then
    sed -i "s/.*innodb_log_buffer_size.*/innodb_log_buffer_size = $MYSQL_innodb_log_buffer_size/" /etc/mysql/my.cnf         
fi

if [ -n "${MYSQL_max_allowed_packet}" ]; then
    sed -i "s/.*max_allowed_packet.*/max_allowed_packet = $MYSQL_max_allowed_packet/" /etc/mysql/my.cnf         
fi

if [ -n "${MYSQL_thread_cache_size}" ]; then
    sed -i "s/.*thread_cache_size.*/thread_cache_size = $MYSQL_thread_cache_size/" /etc/mysql/my.cnf         
fi
if [ -n "${MYSQL_sort_buffer_size}" ]; then
    sed -i "s/.*sort_buffer_size.*/sort_buffer_size = $MYSQL_sort_buffer_size/" /etc/mysql/my.cnf         
fi
if [ -n "${MYSQL_bulk_insert_buffer_size}" ]; then
    sed -i "s/.*bulk_insert_buffer_size.*/bulk_insert_buffer_size = $MYSQL_bulk_insert_buffer_size/" /etc/mysql/my.cnf         
fi
if [ -n "${MYSQL_tmp_table_size}" ]; then
    sed -i "s/.*tmp_table_size.*/tmp_table_size = $MYSQL_tmp_table_size/" /etc/mysql/my.cnf         
fi
if [ -n "${MYSQL_max_heap_table_size}" ]; then
    sed -i "s/.*max_heap_table_size.*/max_heap_table_size = $MYSQL_max_heap_table_size/" /etc/mysql/my.cnf         
fi  
if [ -n "${MYSQL_key_buffer_size}" ]; then
    sed -i "s/.*key_buffer_size.*/key_buffer_size = $MYSQL_key_buffer_size/" /etc/mysql/my.cnf         
fi 
if [ -n "${MYSQL_max_connections}" ]; then
    sed -i "s/.*max_connections.*/max_connections = $MYSQL_max_connections/" /etc/mysql/my.cnf         
fi 

if [ -n "${MYSQL_innodb_force_recovery}" ]; then
    sed -i "s/.*innodb_force_recovery.*/innodb_force_recovery = $MYSQL_innodb_force_recovery/" /etc/mysql/my.cnf         
fi 

# avoid race condition when mysql starts before the config file is closed
sleep 1

if [ "$1" = 'mysqld' ]; then
    # Get config
    #this crashes on 10.1
    #DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
    DATADIR=/var/lib/mysql

    # only initialize if this is master , otherwise it the node add command will do this
    if [ ! -d "$DATADIR/mysql" ] && [ -n "${MYSQL_PRIMARY}" ]; then
            if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
                    echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
                    echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
                    exit 1
            fi

            mkdir -p "$DATADIR"
            chown -R mysql:mysql "$DATADIR"

            echo 'Initializing database'
            mysql_install_db --user=mysql --datadir="$DATADIR" --rpm
            echo 'Database initialized'

            "$@" &
            pid="$!"

            mysql=( mysql --protocol=socket -uroot )

            for i in {30..0}; do
                    if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
                            break
                    fi
                    echo 'MySQL init process in progress...'
                    sleep 1
            done
            if [ "$i" = 0 ]; then
                    echo >&2 'MySQL init process failed.'
                    exit 1
            fi

            if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
                    # sed is for https://bugs.mysql.com/bug.php?id=20545
                    mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
            fi

            "${mysql[@]}" <<-EOSQL
                    -- What's done in this file shouldn't be replicated
                    --  or products like mysql-fabric won't work
                    SET @@SESSION.SQL_LOG_BIN=0;
                    DELETE FROM mysql.user ;
                    CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
                    GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
                    DROP DATABASE IF EXISTS test ;
                    FLUSH PRIVILEGES ;
EOSQL

            if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
                    mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
            fi

            if [ "$MYSQL_DATABASE" ]; then
                    echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
                    mysql+=( "$MYSQL_DATABASE" )
            fi

            if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
                    echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" | "${mysql[@]}"

                    if [ "$MYSQL_DATABASE" ]; then
                            echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" | "${mysql[@]}"
                    fi

                    echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
            fi

            echo
            for f in /docker-entrypoint-initdb.d/*; do
                    case "$f" in
                            *.sh)  echo "$0: running $f"; . "$f" ;;
                            *.sql) echo "$0: running $f"; "${mysql[@]}" < "$f" && echo ;;
                            *)     echo "$0: ignoring $f" ;;
                    esac
                    echo
            done

            if ! kill -s TERM "$pid" || ! wait "$pid"; then
                    echo >&2 'MySQL init process failed.'
                    exit 1
            fi

            echo
            echo 'MySQL init process done. Ready for start up.'
            echo
    fi

    chown -R mysql:mysql "$DATADIR"
    if [ -n "${MYSQL_PRIMARY}" ]; then
        set -- mysqld --wsrep-new-cluster
    fi
fi

# without this is fails to sync with the master
rm -Rf "$DATADIR/sst_in_progress"
rm -Rf "$DATADIR/.sst"
exec "$@"