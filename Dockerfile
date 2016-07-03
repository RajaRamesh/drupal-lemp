FROM debian:latest

# Set variables.
ENV MYSQL_PASS=123 \
    DRUSH_VERSION='8.1.2' \
    DCG_VERSION='1.9.1' \
    PHPMYADMIN_VERSION='4.6.3' \
    HOST_USER_NAME=lemp \
    HOST_USER_UID=1000 \
    HOST_USER_PASS=123 \
    TIMEZONE=Europe/Moscow \
    DEBIAN_FRONTEND=noninteractive

# Set server timezone.
RUN echo $TIMEZONE | tee /etc/timezone && dpkg-reconfigure tzdata

# Install dotdeb repo.
RUN apt-get update \
    && apt-get install -y curl \
    && echo "deb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list \
    && curl -sS https://www.dotdeb.org/dotdeb.gpg | apt-key add -

# Install required packages.
RUN apt-get update && apt-get -y install \
  sudo supervisor net-tools wget git vim zip unzip mc sqlite3 tree tmux ncdu \
  bash-completion nodejs nodejs-legacy npm nginx mysql-server mysql-client php7.0-xml \
  php7.0-mysql php7.0-curl php7.0-gd php7.0-json php7.0-mbstring php7.0-cgi php7.0-fpm \
  php7.0 php7.0-xdebug
  
# Copy sudoers file
COPY sudoers /etc/sudoers
  
# Update default nginx configuration.
COPY default /etc/nginx/sites-available/default

# Create runtime directory for php-fpm.
RUN mkdir /run/php

# Change mysql root password.
RUN service mysql start && mysqladmin -u root password $MYSQL_PASS

# Fix mysql directory onwer.
#RUN chown -R mysql:mysql /var/lib/mysql

# Change php settings.
COPY 20-development-fpm.ini /etc/php/7.0/fpm/conf.d/20-development.ini
COPY 20-development-cli.ini /etc/php/7.0/cli/conf.d/20-development.ini
COPY 20-xdebug.ini /etc/php/7.0/fpm/conf.d/20-xdebug.ini
COPY 20-xdebug.ini /etc/php/7.0/cli/conf.d/20-xdebug.ini
    
# Create host user.
RUN useradd $HOST_USER_NAME -m -u$HOST_USER_UID -Gsudo
RUN echo $HOST_USER_NAME:$HOST_USER_PASS | chpasswd
  
# Add dot files.
COPY bashrc /home/$HOST_USER_NAME/.bashrc
COPY vimrc /home/$HOST_USER_NAME/.vimrc
COPY gitconfig /home/$HOST_USER_NAME/.gitconfig

# Install PhpMyAdmin
RUN cd /tmp \
    && wget http://files.directadmin.com/services/all/phpMyAdmin/phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.tar.gz \
    && tar -xf phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.tar.gz \
    && mv phpMyAdmin-$PHPMYADMIN_VERSION-all-languages /var/www/phpmyadmin

# Install composer.
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Install convert.php
RUN cd /tmp \
    && wget https://raw.githubusercontent.com/thomasbachem/php-short-array-syntax-converter/master/convert.php \
    && chmod +x convert.php \
    && mv convert.php /usr/local/bin/convert.php
     
# Install Drush.
RUN wget https://github.com/drush-ops/drush/releases/download/$DRUSH_VERSION/drush.phar && chmod +x drush.phar && mv drush.phar /usr/local/bin/drush

# Enable drush completion.
COPY drush.complete.sh /etc/bash_completion.d/drush.complete.sh

# Install phpcs
RUN wget https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar && chmod +x phpcs.phar && mv phpcs.phar /usr/local/bin/phpcs

# Install drupalcs
RUN cd /usr/share/php && drush dl coder && phpcs --config-set installed_paths /usr/share/php/coder/coder_sniffer 

# Install DCG.
RUN wget https://github.com/Chi-teck/drupal-code-generator/releases/download/$DCG_VERSION/dcg.phar && chmod +x dcg.phar && mv dcg.phar /usr/local/bin/dcg

# Install Drupal Console.
RUN curl https://drupalconsole.com/installer -L -o drupal.phar && mv drupal.phar /usr/local/bin/drupal && chmod +x /usr/local/bin/drupal

# Add supervisor configuration.
COPY supervisor.conf /etc/supervisor/conf.d/supervisor.conf

# Copy cmd.sh.
COPY cmd.sh /cmd.sh
RUN chmod +x /cmd.sh

# Copy mysql data to a temporary location. 
RUN mkdir /var/lib/_mysql && cp -R /var/lib/mysql/* /var/lib/_mysql

# Copy cmd.sh.
COPY mysql-init.sh /usr/bin/mysql-init.sh
RUN chmod +x /usr/bin/mysql-init.sh

# Set host user directory owner
RUN chown -R $HOST_USER_NAME:$HOST_USER_NAME /home/$HOST_USER_NAME

# Empty /tmp directory.
RUN rm -rf /tmp/*

CMD ["/usr/bin/supervisord", "-n"]
