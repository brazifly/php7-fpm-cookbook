default['php7']['version'] = '7.0.3'
default['php7']['timezone'] = 'Europe\Bratislava'
default['php7']['common-conf-string'] = '--prefix=/usr/local/php7 --enable-bcmath --with-bz2 --with-zlib --enable-zip --enable-calendar --enable-exif --enable-ftp --with-gettext --with-gd --with-jpeg-dir --with-png-dir --with-freetype-dir --with-xpm-dir --enable-mbstring --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-openssl --enable-intl --enable-soap --with-readline --with-curl --with-mcrypt --with-xsl --with-openssl --disable-cgi'
default['php7']['fpm-conf-string'] = '--with-config-file-path=/etc/php7/fpm --with-config-file-scan-dir=/etc/php7/fpm/conf.d --disable-cli --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data'
default['php7']['cli-conf-string'] = '--enable-pcntl --with-config-file-path=/etc/php7/cli --with-config-file-scan-dir=/etc/php7/cli/conf.d'

