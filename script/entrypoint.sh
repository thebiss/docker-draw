#!/bin/bash
set -e

if [ -z "$MYSQL_PORT_3306_TCP_ADDR" ]; then
	echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable'
	echo >&2 '  Did you forget to --link some_mysql_container:mysql ?'
	exit 1
fi

# if we're linked to MySQL, and we're using the root user, and our linked
# container has a default "root" password set up and passed through... :)
: ${DRAW_DB_USER:=root}
if [ "$DRAW_DB_USER" = 'root' ]; then
	: ${DRAW_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
fi
: ${DRAW_DB_NAME:=draw}

DRAW_DB_NAME=$( echo $DRAW_DB_NAME | sed 's/\./_/g' )

if [ -z "$DRAW_DB_PASSWORD" ]; then
	echo >&2 'error: missing required DRAW_DB_PASSWORD environment variable'
	echo >&2 '  Did you forget to -e DRAW_DB_PASSWORD=... ?'
	echo >&2
	echo >&2 '  (Also of interest might be DRAW_DB_USER and DRAW_DB_NAME.)'
	exit 1
fi

DRAW_DB_HOST="${MYSQL_PORT_3306_TCP_ADDR}"

: ${DRAW_TITLE:=Draw}
: ${DRAW_SESSION_KEY:=$(
                node -p "require('crypto').randomBytes(32).toString('hex')")}

# Check if database already exists
RESULT=`mysql -u${DRAW_DB_USER} -p${DRAW_DB_PASSWORD} \
        -h${DRAW_DB_HOST} --skip-column-names \
        -e "SHOW DATABASES LIKE '${DRAW_DB_NAME}'"`

if [ "$RESULT" != $DRAW_DB_NAME ]; then
        # mysql database does not exist, create it
        echo "Creating database ${DRAW_DB_NAME}"

        mysql -u${DRAW_DB_USER} -p${DRAW_DB_PASSWORD} \
              -h${DRAW_DB_HOST} \
              -e "create database ${DRAW_DB_NAME}"
fi

cat << EOF > settings.json
{
  "title": "${DRAW_TITLE}",
  "ip": "0.0.0.0",
  "port" : 9002,
  "sessionKey" : "${DRAW_SESSION_KEY}",
  "dbType" : "mysql",
  "dbSettings" : {
                    "user"    : "${DRAW_DB_USER}",
                    "host"    : "${DRAW_DB_HOST}",
                    "password": "${DRAW_DB_PASSWORD}",
                    "database": "${DRAW_DB_NAME}"
                  }
EOF

if [ $DRAW_ADMIN_PASSWORD ]; then
        : ${DRAW_ADMIN_USER:=admin}

cat << EOF >> settings.json
  ,
  "users": {
    "${DRAW_ADMIN_USER}": {
      "password": "${DRAW_ADMIN_PASSWORD}",
      "is_admin": true
    }
  },
EOF

fi

cat << EOF >> settings.json
}
EOF

exec "$@"

