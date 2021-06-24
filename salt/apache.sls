---
# SECRETS DIRECTORY
# A directory with very tight permissions to store secrets.  At present there will only be one subdirectory created,
# certbot/ which will be used for storing Certbot secrets.
secrets_dir:
  file.directory:
    - name: /root/.secrets
    - user: root
    - group: root
    - dir_mode: 700
    - file_mode: 600

# CERTBOT DIRECTORY
# Secrets for Certbot, the autonomous TLS certificate deployment tool.  Permissions for this directory are similarly
# very tight because of the sensitive data being stored.
certbot_dir:
  file.directory:
    - name: /root/.secrets/certbot
    - user: root
    - group: root
    - dir_mode: 700
    - file_mode: 600
    - require:
      - file: secrets_dir

{%- set dns_credentials = salt['pillar.get']('letsencrypt:dns_credentials') %}

# CLOUDFLARE SECRETS FILE
# CloudFlare API secrets for use by the Certbot CloudFlare DNS plugin.  At present, the package in the Ubuntu
# repositories is old and doesn't support the use of an API token.  When this is updated, the email and API key will not
# need to specified (only the API token).
cloudflare_ini:
  file.managed:
    - name: /root/.secrets/certbot/cloudflare.ini
    - user: root
    - group: root
    - mode: 600
    - template: jinja
    - contents: |
        # Cloudflare API credentials used by Certbot
        dns_cloudflare_email = {{ dns_credentials.email }}
        dns_cloudflare_api_key = {{ dns_credentials.api_key }}

        # # Cloudflare API token used by Certbot
        # dns_cloudflare_api_token = {{ dns_credentials.api_token }}
    - require:
      - file: certbot_dir

# INSTALL AND ENABLE APACHE WEBSERVER
# This will be used to serve HTML files from Munin.
apache_package:
  pkg.installed:
    - name: apache2
  service.running:
    - name: apache2
    - enable: true
    - reload: true

# ENABLE SSL APACHE MODULE
# Provides SSL v3 and TLS v1.x support.  This module is required by the Mozilla recommended Apache configuration (which
# is used by the salt01.dylanw.net site).
ssl_module:
  apache_module.enabled:
    - name: ssl
    - watch_in:
      - service: apache_package

# ENABLE SOCACHE_SHMCB APACHE MODULE
# Shared object cache provider which provides for creation and access to a cache.  This module is required by the
# Mozilla recommended Apache configuration (which is used by the salt01.dylanw.net site).
socache_shmcb_module:
  apache_module.enabled:
    - name: socache_shmcb
    - watch_in:
      - service: apache_package

# ENABLE REWRITE APACHE MODULE
# Rule-based rewriting engine to rewrite requested URLs on the fly.  This module is required by the Mozilla recommended
# Apache configuration (which is used by the salt01.dylanw.net site).
rewrite_module:
  apache_module.enabled:
    - name: rewrite
    - watch_in:
      - service: apache_package

# ENABLE HEADERS APACHE MODULE
# Provides directives to control and modify HTTP request and response headers.  This module is required by the Mozilla
# recommended Apache configuration (which is used by the salt01.dylanw.net site).
headers_module:
  apache_module.enabled:
    - name: headers
    - watch_in:
      - service: apache_package

{%- set testing = salt['pillar.get']('testing') %}

# ENABLE APACHE SITE SALT01.DYLANW.NET
# Get SSL certificate for Apache, if the testing variable is set to true in pillars the Let's Encrypt staging server
# will be used instead of issuing a real certificate.  Deploy configuration for salt01.dylanw.net using the Mozilla
# recommended TLS configuration and enable the site.
salt01_dylanw_net:
  acme.cert:
    - name: salt01.dylanw.net
    - email: webmaster@dylanw.net
    - dns_plugin: cloudflare
    - dns_plugin_credentials: /root/.secrets/certbot/cloudflare.ini
    {% if testing %}
    - server: https://acme-staging-v02.api.letsencrypt.org/directory
    {% endif %}
    - require:
      - file: cloudflare_ini
  file.managed:
    - name: /etc/apache2/sites-available/salt01.dylanw.net.conf
    - contents: |
        # generated 2021-04-22, Mozilla Guideline v5.6, Apache 2.4.41, OpenSSL 1.1.1d, intermediate configuration
        # https://ssl-config.mozilla.org/#server=apache&version=2.4.41&config=intermediate&openssl=1.1.1d&guideline=5.6

        # this configuration requires mod_ssl, mod_socache_shmcb, mod_rewrite, and mod_headers
        <VirtualHost *:80>
          RewriteEngine On
          RewriteCond %{REQUEST_URI} !^/\.well\-known/acme\-challenge/
          RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
        </VirtualHost>

        <VirtualHost *:443>
          ServerAdmin webmaster@localhost
          DocumentRoot /var/www/html

          ErrorLog ${APACHE_LOG_DIR}/error.log
          CustomLog ${APACHE_LOG_DIR}/access.log combined

          SSLEngine on

          # curl https://ssl-config.mozilla.org/ffdhe2048.txt >> /path/to/signed_cert_and_intermediate_certs_and_dhparams
          SSLCertificateFile      /etc/letsencrypt/live/salt01.dylanw.net/fullchain.pem
          SSLCertificateKeyFile   /etc/letsencrypt/live/salt01.dylanw.net/privkey.pem

          # enable HTTP/2, if available
          Protocols h2 http/1.1

          # HTTP Strict Transport Security (mod_headers is required) (63072000 seconds)
          Header always set Strict-Transport-Security "max-age=63072000"
        </VirtualHost>

        # intermediate configuration
        SSLProtocol             all -SSLv3 -TLSv1 -TLSv1.1
        SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        SSLHonorCipherOrder     off
        SSLSessionTickets       off

        SSLUseStapling On
        SSLStaplingCache "shmcb:logs/ssl_stapling(32768)"
    - require:
      - acme: salt01_dylanw_net
      - apache_module: ssl_module
      - apache_module: socache_shmcb_module
      - apache_module: rewrite_module
      - apache_module: headers_module
  apache_site.enabled:
    - name: salt01.dylanw.net
    - require:
      - file: salt01_dylanw_net
    - watch_in:
      - service: apache_package

# DISABLE DEFAULT HTTP SITE
# Disable the default 000-default site provided with the apache2 package.  Disabling this and the default HTTPS site
# will ensure all requests are sent to the salt01.dylanw.net site we previously enabled.
default_http:
  apache_site.disabled:
    - name: 000-default
    - watch_in:
      - service: apache_package

# DISABLE DEFAULT HTTPS SITE
# Disable the default default-ssl site provided with the apache2 package.  Disabling this and the default HTTP site will
# ensure all requests are sent to the salt01.dylanw.net site we previously enabled.
default_https:
  apache_site.disabled:
    - name: default-ssl
    - watch_in:
      - service: apache_package
