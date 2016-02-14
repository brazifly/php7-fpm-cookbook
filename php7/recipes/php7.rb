# Helper to identify if php7 is already installed
module Php7Helper
  include Chef::Mixin::ShellOut

  def php7_installed?
    cmd = shell_out("php -v | grep -q #{node['php7']['version']}")
    if (cmd.exitstatus == 0)
      return true
    else
      return false
    end
  end
end

Chef::Resource.send(:include, Php7Helper)

# Update package list
bash 'update_package_list' do
  code <<-EOH
    sudo apt-get update
    EOH
  not_if { php7_installed? }
end

# Install needed packages
package [
    "make",
    "bison",
    "g++",
    "autoconf",
    "libxml2-dev",
    "libbz2-dev",
    "libcurl4-openssl-dev",
    "libltdl-dev",
    "libpng12-dev",
    "libjpeg-turbo8-dev",
    "libfreetype6-dev",
    "libxpm-dev",
    "libimlib2-dev",
    "libicu-dev",
    "libreadline6-dev",
    "libmcrypt-dev",
    "libxslt1-dev"
  ]  do
  action :install
  not_if { php7_installed? }
end

# Create some more directories
%w{/etc/php7/conf.d /etc/php7/cli/conf.d /etc/php7/fpm/conf.d /usr/local/php7 /etc/php7/fpm/pool.d}.each do |dir|
  directory "#{dir}" do
    mode "0755"
    owner "root"
    group "root"
    action :create
    recursive true
    not_if { php7_installed? }
  end
end

# Clone PHP 7 repository
git "clone_php7" do
    destination "/usr/local/src/php7"
    repository "https://git.php.net/repository/php-src.git"
    action :sync
    depth 1
    branch "PHP-#{node['php7']['version']}"
    checkout_branch "PHP-#{node['php7']['version']}"
    not_if { php7_installed? }
end

# Build PHP 7 fpm
bash "build_php7_fpm" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code <<-EOH
        ./buildconf --force
    EOH
    not_if { php7_installed? }
end

# Configure php7 fpm build
bash "configure_php7_fpm_build" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code <<-EOH
        ./configure #{node['php7']['common-conf-string']} #{node['php7']['fpm-conf-string']}
    EOH
    not_if { php7_installed? }
end

# Make PHP 7 fpm
bash "make_php7_fpm" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code "make"
    not_if { php7_installed? }
end

# Install PHP 7 fpm
bash "install_php7_fpm" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code "make install"
    not_if { php7_installed? }
end

# Create php fpm ini
file "create_php_fpm_ini" do
  action :create
  path "/etc/php7/fpm/php.ini"
  owner "root"
  group "root"
  content lazy { IO.read("/usr/local/src/php7/php.ini-production") }
  not_if { php7_installed? }
end

# Adjust php fpm ini
ruby_block "adjust_php_fpm_ini" do
  block do
    sed = Chef::Util::FileEdit.new("/etc/php7/fpm/php.ini")
    sed.search_file_replace(/;date.timezone =.*/, "date.timezone = #{node['php7']['timezone']}")
    sed.search_file_replace(/;opcache.enable=.*/, "opcache.enable = 1")
    sed.write_file
  end
  not_if { php7_installed? }
end if platform_family?('debian')

# Create php fpm conf
file "create_php_fpm_conf" do
  action :create
  path "/etc/php7/fpm/php-fpm.conf"
  owner "root"
  group "root"
  content lazy { IO.read("/usr/local/src/php7/sapi/fpm/php-fpm.conf.in") }
  not_if { php7_installed? }
end

# Adjust fpm pool
ruby_block "adjust_fpm_pool" do
  block do
    sed = Chef::Util::FileEdit.new("/etc/php7/fpm/php-fpm.conf")
    sed.search_file_replace(/^include=.*\//, "include=/etc/php7/fpm/pool.d/")
    sed.write_file
  end
  not_if { php7_installed? }
end if platform_family?('debian')

# Create www conf
file "create_www_conf" do
  action :create
  path "/etc/php7/fpm/pool.d/www.conf"
  owner "root"
  group "root"
  content lazy { IO.read("/usr/local/php7/etc/php-fpm.d/www.conf.default") }
  not_if { php7_installed? }
end

# Adjust www conf
ruby_block "adjust_www_conf" do
  block do
    sed = Chef::Util::FileEdit.new("/etc/php7/fpm/pool.d/www.conf")
    sed.search_file_replace(/listen = 127.0.0.1:9000/, "listen = /run/php7-fpm.sock")
    sed.search_file_replace(/;listen.owner = www-data/, "listen.owner = www-data")
    sed.search_file_replace(/;listen.group = www-data/, "listen.group = www-data")
    sed.write_file
  end
  not_if { php7_installed? }
end if platform_family?('debian')

# Create php fpm init.d script
file "create_php_fpm_init" do
  action :create
  path "/etc/init.d/php7-fpm"
  owner "root"
  group "root"
  mode "0755"
  content lazy { IO.read("/usr/local/src/php7/sapi/fpm/init.d.php-fpm") }
  not_if { php7_installed? }
end

# Adjust php fpm init.d script
ruby_block "adjust_php_fpm_init" do
  block do
    sed = Chef::Util::FileEdit.new("/etc/init.d/php7-fpm")
    sed.search_file_replace(/Provides:          php-fpm/, "Provides:          php7-fpm")
    sed.search_file_replace(/^php_fpm_CONF=.*/, "php_fpm_CONF=/etc/php7/fpm/php-fpm.conf")
    sed.search_file_replace(/^php_fpm_PID=.*/, "php_fpm_PID=/var/run/php7-fpm.pid")
    sed.write_file
  end
  not_if { php7_installed? }
end if platform_family?('debian')

# Update php7 fpm init link
bash "update_php7_fpm_init_link" do
    user "root"
    group "root"
    code "update-rc.d php7-fpm defaults"
    not_if { php7_installed? }
end

# SAPI cleanup
bash "sapi_cleanup" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code "make distclean"
    not_if { php7_installed? }
end

# Build PHP 7 cli
bash "build_php7_cli" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code <<-EOH
        ./buildconf --force
    EOH
    not_if { php7_installed? }
end

# Configure php cli build
bash "configure_php7_cli_build" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code <<-EOH
        ./configure #{node['php7']['common-conf-string']} #{node['php7']['cli-conf-string']}
    EOH
    not_if { php7_installed? }
end

# Make PHP 7 cli
bash "make_php7_cli" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code "make"
    not_if { php7_installed? }
end

# Install PHP 7 cli
bash "install_php7_cli" do
    cwd "/usr/local/src/php7"
    user "root"
    group "root"
    code "make install"
    not_if { php7_installed? }
end

# Create php cli ini
file "create_php_cli_ini" do
  action :create
  path "/etc/php7/cli/php.ini"
  owner "root"
  group "root"
  content lazy { IO.read("/usr/local/src/php7/php.ini-production") }
  not_if { php7_installed? }
end

# Adjust php cli ini
ruby_block "adjust_php_cli_ini" do
  block do
    sed = Chef::Util::FileEdit.new("/etc/php7/cli/php.ini")
    sed.search_file_replace(/;date.timezone =.*/, "date.timezone = #{node['php7']['timezone']}")
    sed.write_file
  end
  not_if { php7_installed? }
end if platform_family?('debian')

# Create alternative symlink
link 'create_alternative_symlink' do
  target_file '/etc/alternatives/php'
  to '/usr/local/php7/bin/php'
  link_type :symbolic
  not_if { php7_installed? }
end

# Create opcache ini
file "create_opcache_ini" do
  action :create
  path "/etc/php7/conf.d/opcache.ini"
  owner "root"
  group "root"
  content lazy { "zend_extension=opcache.so" }
  not_if { php7_installed? }
end

# Enable opcache fpm
link "enable_opcache_fpm" do
  target_file '/etc/php7/fpm/conf.d/opcache.ini'
  to '/etc/php7/conf.d/opcache.ini'
  link_type :symbolic
  not_if { php7_installed? }
end

# Enable opcache cli
link "enable_opcache_cli" do
  target_file '/etc/php7/cli/conf.d/opcache.ini'
  to '/etc/php7/conf.d/opcache.ini'
  link_type :symbolic
   not_if { php7_installed? }
end

# Create bin symlink
link 'create_bin_symlink' do
  target_file '/usr/bin/php'
  to '/etc/alternatives/php'
  link_type :symbolic
  not_if { php7_installed? }
end

# Start php fpm service
service "start_php_fpm" do
  service_name "php7-fpm"
  supports :restart => true
  action :restart
end
