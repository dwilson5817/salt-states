---
# INSTALL LIBRARIES MODULES FOR MUNIN
# Install the necessary packages to run the Munin CGI script.  libcgi-fast-perl: CGI subclass for work with FCGI.
# libapache2-mod-fcgid: FastCGI interface module for Apache 2.
munin_modules:
  pkg.installed:
    - pkgs:
      - libcgi-fast-perl
      - libapache2-mod-fcgid
    - require:
      - pkg: apache_package

# ENABLE FCGID MODULE
# Enable the fcgid Apache module.  The Apache service will also be reloaded.  FastCGI is used by Munin to enable zooming
# in on graphs.  This module is optional, but it provides the ability to zoom in with no drawbacks.
fcgid_module:
  apache_module.enabled:
    - name: fcgid
    - require:
      - pkg: munin_modules
    - watch_in:
      - service: apache_package

# DEPLOY MUNIN APACHE CONFIGURATION
# This configuration exposes the Munin HTML files at /munin.  Munin will be accessible on all hosts, although no
# websites are hosted on this box so this will likely only be the hostname.
munin_conf:
  file.managed:
    - name: /etc/apache2/conf-available/munin.conf
    - contents: |
        Alias /munin /var/cache/munin/www
        <Directory /var/cache/munin/www>
          # Require local
          Require all granted
          Options FollowSymLinks SymLinksIfOwnerMatch
          Options None
        </Directory>
        ScriptAlias /munin-cgi/munin-cgi-graph /usr/lib/munin/cgi/munin-cgi-graph
        <Location /munin-cgi/munin-cgi-graph>
          Require all granted
          Options FollowSymLinks SymLinksIfOwnerMatch
          <IfModule mod_fcgid.c>
            SetHandler fcgid-script
          </IfModule>
          <IfModule !mod_fcgid.c>
            SetHandler cgi-script
          </IfModule>
        </Location>
  apache_conf.enabled:
    - name: munin
    - require:
      - file: munin_conf
    - watch_in:
      - service: apache_package
