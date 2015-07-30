# /bin/bash

if [ "$1" == "" ]; then
        echo "no container name given so restarting all conatiners"
        docker rm -f $(docker ps -aq)
else
        echo "Removing $1"
        docker rm -f $1
fi

cn="mysql1"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d  \
		-p 127.0.0.1:3306:3306 \
		-v /home/mysql:/var/lib/mysql \
		-v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		-e MYSQL_ROOT_PASSWORD=aaaa  \
		vipconsult/mysql
fi

cn="psql1"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d \
		-p 127.0.0.1:5432:5432 \
		-v /home/postgresql:/var/lib/postgresql/data \
		-v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		-e PG_LOCALE="en_GB.UTF-8 UTF-8" \
		vipconsult/pgsql93
fi

cn="smtp"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
        docker run --restart=always -d --name $cn \
		-v /etc/localtime:/etc/localtime:ro \
		-v /etc/timezone:/etc/timezone:ro \
                -h vip-consult.co.uk \
                -p 127.0.0.1:25:25 \
                vipconsult/smtp
fi

cn="php53"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d \
		-v /var/run:/var/run \
		-v /home/http:/home/http  \
                -v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		--link mysql1:mysql1  \
		--link psql1:psql1  \
		--link smtp:smtp \
                -e "smtpServer=smtp" \
		-h vip-consult.co.uk \
		vipconsult/php53
fi

cn="php"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d \
		-v /var/run:/var/run \
		-v /home/http:/home/http  \
                -v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		--link mysql1:mysql1  \
		--link psql1:psql1 \
		--link smtp:smtp \
                -e "smtpServer=smtp" \
		-h vip-consult.co.uk \
		vipconsult/php
fi

cn="simplehelp"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d \
		-v /home/simplehelp:/home/simplehelp  \
                -v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		--net=host \
		vipconsult/simplehelp
fi

cn="nginx"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d \
		-v /home/http:/home/http \
		-v /var/run:/var/run \
                -v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		-p 178.79.150.62:80:80 \
		-p 178.79.150.62:443:443 \
		vipconsult/nginx-pagespeed nginx -c /home/http/default/main.conf -g "daemon off;"
fi

cn="cron"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d \
		--link mysql1:mysql1 \
		-v /home/http:/home/http  \
                -v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		-v /home/cron/cron.daily:/etc/cron.daily \
		vipconsult/cron
fi

cn="proftpd"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	sudo rmdir /home/proftpd/ftpd.passwd
	sudo mkdir -p /home/proftpd
	sudo touch /home/proftpd/ftpd.passwd

	docker run --name $cn --restart=always -d \
		--net=host \
		-v /home/:/home/ \
                -v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		-v /home/proftpd/ftpd.passwd:/etc/proftpd/ftpd.passwd \
		vipconsult/proftpd
fi

cn="logrotate"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	docker run --name $cn --restart=always -d \
		-v /var/lib/docker:/var/lib/docker \
		-h vip-consult.co.uk \
		-v /etc/localtime:/etc/localtime:ro \
                -v /etc/timezone:/etc/timezone:ro \
		vipconsult/logrotate
fi

cn="fs"
if [ "$1" == "" ] || [ $1 == $cn ] ;then
echo "Starting $cn"
	sudo docker run --name $cn \
        	--restart=always -d \
	        -v /home/freeswitch/sounds:/usr/local/freeswitch/sounds \
        	-v /home/freeswitch/conf:/usr/local/freeswitch/conf \
		-v /home/freeswitch/ssl:/usr/local/freeswitch/ssl \
		-v /etc/localtime:/etc/localtime:ro \
		-v /etc/timezone:/etc/timezone:ro \
	        --net=host \
	        vipconsult/freeswitch
fi
