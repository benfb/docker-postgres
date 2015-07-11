#!/bin/bash
set -e
chown -R postgres "$PGDATA"

if [ -z "$(ls -A "$PGDATA")" ]; then
    gosu postgres initdb
    sed -ri "s/^#(listen_addresses\s*=\s*)\S+/\1'*'/" "$PGDATA"/postgresql.conf

    : ${POSTGRES_USER:="postgres"}

    if [ "$POSTGRES_PASSWORD" ]; then
      pass="PASSWORD '$POSTGRES_PASSWORD'"
      authMethod=md5
    else
      echo "==============================="
      echo "!!! Use \$POSTGRES_PASSWORD env var to secure your database !!!"
      echo "==============================="
      pass=
      authMethod=trust
    fi
    echo

    if [ -n "${POSTGRES_USER}" ]; then
      echo "Creating user \"${POSTGRES_USER}\"..."
      echo "CREATE ROLE ${POSTGRES_USER} with LOGIN CREATEDB PASSWORD '${POSTGRES_PASSWORD}';" | gosu postgres postgres --single -jE
      echo
    fi

    if [ -n "${POSTGRES_DB}" ]; then
        for db in $(awk -F',' '{for (i = 1 ; i <= NF ; i++) print $i}' <<< "${POSTGRES_DB}"); do
          echo "Creating database \"${db}\"..."
          echo "CREATE DATABASE ${db}" | gosu postgres postgres --single -jE
          if [ -n "${POSTGRES_USER}" ]; then
            echo "Granting access to database \"${db}\" for user \"${POSTGRES_USER}\"..."
            echo "GRANT ALL PRIVILEGES ON DATABASE ${db} TO $POSTGRES_USER" | gosu postgres postgres --single -jE
            echo "ALTER DATABASE ${db} OWNER TO $POSTGRES_USER" | gosu postgres postgres --single -jE
          fi


          userSql="CREATE USER $POSTGRES_USER WITH SUPERUSER $pass;"
          echo $userSql | gosu postgres postgres --single -jE
        done

        { echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA"/pg_hba.conf
    fi
fi

exec gosu postgres "$@"
