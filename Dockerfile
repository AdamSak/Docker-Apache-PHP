FROM phusion/baseimage:jammy-1.0.0
MAINTAINER adamsak

# Set correct environment variables
ENV DEBIAN_FRONTEND noninteractive
ENV HOME            /root
ENV LC_ALL          C.UTF-8
ENV LANG            en_US.UTF-8
ENV LANGUAGE        en_US.UTF-8
ENV TERM xterm


# Use baseimage-docker's init system
CMD ["/sbin/my_init"]


# Configure user nobody to match unRAID's settings
RUN \
  usermod -u 99 nobody && \
  usermod -g 100 nobody && \
  usermod -d /home nobody && \
  chown -R nobody:users /home


RUN apt-get update
RUN add-apt-repository ppa:ondrej/php
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y mc
RUN apt-get install -y tmux
RUN apt-get install -y php7.4-mysql
RUN apt-get install -y php7.4-mysqlnd


# Install proxy Dependencies
RUN apt-get update -y
RUN apt-get install -y apache2
RUN apt-get install -y php7.4 libapache2-mod-php7.4 php7.4-mcrypt php7.4-cli php7.4-xml php7.4-zip \
                       php7.4-mysql php7.4-gd php7.4-imagick php7.4-tidy php7.4-xmlrpc \
                       php-curl php7.4-mbstring php7.4-soap php7.4-intl php7.4-ldap php7.4-imap php-xml \
                       php7.4-sqlite php7.4-mcrypt inotify-tools php7.4-common

# Additional stuff
RUN apt-get install -y php7.4-json php7.4-opcache php7.4-readline apache2-utils vim curl zip \
                       php7.4-gettext graphicsmagick screen

RUN phpenmod mbstring

RUN apt-get clean -y
RUN rm -rf /var/lib/apt/lists/*
 
RUN \
  service apache2 restart && \
  rm -R -f /var/www && \
  ln -s /web /var/www
  
# Update apache configuration with this one
RUN \
  mv /etc/apache2/sites-available/000-default.conf /etc/apache2/000-default.conf && \
  rm /etc/apache2/sites-available/* && \
  rm /etc/apache2/apache2.conf && \
  ln -s /config/proxy-config.conf /etc/apache2/sites-available/000-default.conf && \
  ln -s /var/log/apache2 /logs

ADD proxy-config.conf /etc/apache2/000-default.conf
ADD apache2.conf /etc/apache2/apache2.conf
ADD ports.conf /etc/apache2/ports.conf

# Manually set the apache environment variables in order to get apache to work immediately.
RUN \
  echo www-data > /etc/container_environment/APACHE_RUN_USER && \
  echo www-data > /etc/container_environment/APACHE_RUN_GROUP && \
  echo /var/log/apache2 > /etc/container_environment/APACHE_LOG_DIR && \
  echo /var/lock/apache2 > /etc/container_environment/APACHE_LOCK_DIR && \
  echo /var/run/apache2.pid > /etc/container_environment/APACHE_PID_FILE && \
  echo /var/run/apache2 > /etc/container_environment/APACHE_RUN_DIR

# Expose Ports
EXPOSE 80 443

# The www directory and proxy config location
VOLUME ["/config", "/web", "/logs"]

# Add our crontab file
ADD crons.conf /root/crons.conf

# Add firstrun.sh to execute during container startup
ADD firstrun.sh /etc/my_init.d/firstrun.sh
RUN chmod +x /etc/my_init.d/firstrun.sh

# Add inotify.sh to execute during container startup
RUN mkdir /etc/service/inotify
ADD inotify.sh /etc/service/inotify/run
RUN chmod +x /etc/service/inotify/run

# Add apache to runit
RUN mkdir /etc/service/apache
ADD apache-run.sh /etc/service/apache/run
RUN chmod +x /etc/service/apache/run
ADD apache-finish.sh /etc/service/apache/finish
RUN chmod +x /etc/service/apache/finish
RUN a2enmod rewrite
