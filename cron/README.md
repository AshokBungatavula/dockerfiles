# OVERVIEW


We don't mount the docker executable , but only the docker.sock file.
 The image installs the latest docker-engine to be used as a client through the docker.sock socket.
the image creation always installs the latest docker-engine version to be used as client so normally when the host's docker-engine server is older version it might show an error about API mismatch. 
The good news is that docker has this nice env variable DOCKER_API_VERSION which allows newer clients to talk to older servers.




we use supervisor as the cron requires rsyslog so we need to run rsyslog prior the cron daemon so that is uses the rsyslog to send the logs to /var/log/syslog


# CRON EMAILS
	if you don't need emails for the output from the cron jobs than you don't need the smtpContainer and the MAILTO env
	# DOMAINNAME  is used for the email  FROM and TO  fields when  then cron sends the email

# MANUAL RUN (copy and paster)
	the default bridge network doesn't allow communication between containers without using 
	the legacy --link switch so we creat a user defined network
	
	docker network create cronApp
	
	docker run -d \
		--name=smtpContainer \
		--net cronApp \
		-e DOMAINNAME=domain.com \
		-e SMTP_INTERVAL=1m \
		-e SMTP_PROCESSING=queue_only_load_latch \
		-e SMTP_remote_max_parallel=2 \
		-e SMTP_queue_run_max=3 \
		-e SMTP_timeout_frozen_after=3h \
		vipconsult/smtp

	docker run -d \
		--name=cronContainer \
		--net cronApp \
		-v /var/run/docker.sock:/var/run/docker.sock:ro \
		-e DOMAINNAME=domain.com \
		-e DOCKER_API_VERSION=1.23 \
		-e SMTP_SERVER=smtpContainer \
		-e MAILTO=email@domain.com \
		-e CRONTASK_1="* * * * *  root docker run debian echo 'Cron 1 run from docker container'" \
		-e CRONTASK_2="* * * * *  root docker run debian echo 'Cron 2 run from docker container'" \
		vipconsult/cron

# COMPOSE FILE
	version: '2'
	services:
	    cron:
			image: vipconsult/cron
			container_name: cronContainer
			volumes:
			    - /var/run/docker.sock:/var/run/docker.sock:ro
			environment:
			    - DOCKER_API_VERSION=1.23
			    - SMTP_SERVER=smtpContainer
			    - DOMAINNAME=domain.com
			    - MAILTO=email@domain.com
			    - CRONTASK_1=* * * * *  root docker run debian echo 'Cron 1 run from docker container'
			    - CRONTASK_2=* * * * *  root docker run debian echo 'Cron 2 run from docker container'

	    smtp:
			image: vipconsult/smtp
			container_name: smtpContainer
			environment:
			    - DOMAINNAME=domain.com
			    - SMTP_INTERVAL=1m
			    - SMTP_PROCESSING=queue_only_load_latch
			    - SMTP_remote_max_parallel=2
			    - SMTP_queue_run_max=3
			    - SMTP_timeout_frozen_after=3h
		

# LOGS
	docker logs cronContainer
	docker logs smtpContainer
