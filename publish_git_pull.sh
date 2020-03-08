#!/bin/bash

BASEDIR="/your_directory"
BASEURL="ssh://git@repository"
PROJECTNAME="project"

if [ $# -eq 2 ]; then
REPONAME="$1"
BRANCHNAME="$2"
else
INDATA=$(cat <&0)
REPONAME=$(echo $INDATA | jq -r ".repository.name")
BRANCHNAME=$(echo $INDATA | jq -r "." | grep refId | grep heads | cut -d\/ -f3- | cut -d\" -f1)
fi


REPODIR=$(echo $REPONAME | sed 's/[^A-Za-z0-9._-]/_/g' | tr '[:upper:]' '[:lower:]')
BRANCHDIR=$(echo $BRANCHNAME | sed 's/[^A-Za-z0-9._-]/-/g' | tr '[:upper:]' '[:lower:]')
DOMAINNAME=$(echo $BRANCHNAME | sed 's/[^A-Za-z0-9._-]/-/g' | tr '[:upper:]' '[:lower:]')

echo BRANCH normalized: $BRANCHDIR >&2

PARENTDIR="$BASEDIR/$BRANCHDIR"
TARGETDIR="$BASEDIR/$BRANCHDIR/$REPODIR"

mkdir -p "$TARGETDIR"

if [ -e "$TARGETDIR/.git" ]; then
        cd $TARGETDIR
        git stash
        git stash drop
        git checkout $BRANCHNAME
        git pull
else
        cd $TARGETDIR
        git clone "$BASEURL"/"$PROJECTNAME"/"$REPONAME".git .
        git checkout $BRANCHNAME
fi


CONFDIR="$BASEDIR"
CONFFILE="$CONFDIR/$BRANCHDIR.conf"

cat > "$CONFFILE" <<- EOT
server {
        listen       80;
        server_name  ~^$BRANCHDIR\b.*\.yourdomain\.com;
        root            $BASEDIR/$BRANCHDIR/$REPODIR/www;
        index           index.php;
        charset         utf-8;
        rewrite_log     on;
        access_log      $BASEDIR/$BRANCHDIR.access.log main;
        error_log       $BASEDIR/$BRANCHDIR.error.log warn;

        if (!-e \$request_filename){
                rewrite /.* /index.php last;
        }

        location / {
                #fastcgi_pass 127.0.0.1:9000;
                fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
                fastcgi_index index.php;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                fastcgi_param PHP_VALUE "short_open_tag = On";
                include fastcgi_params;

                sendfile                        on;
                tcp_nopush                      off;
                keepalive_requests              0;
        }

        location /static_html {
                try_files \$uri \$uri/ /index.php?/\$request_uri;
        }

        error_page 404 /404.html;
                location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
                location = /50x.html {
        }
}
server {
        listen       443 ssl;
        ssl_certificate "your_ssl_chain";
        ssl_certificate_key "your_ssl_key";
        ssl_session_cache shared:SSL:1m;
        ssl_session_timeout  10m;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        server_name  ~^$BRANCHDIR\b.*\.yourdomain\.com;
        root            $BASEDIR/$BRANCHDIR/$REPODIR/www;
        index           index.php;
        charset         utf-8;
        rewrite_log     on;
        access_log      $BASEDIR/$BRANCHDIR.access.log main;
        error_log       $BASEDIR/$BRANCHDIR.error.log warn;

        if (!-e \$request_filename){
                rewrite /.* /index.php last;
        }

        location / {
                #fastcgi_pass 127.0.0.1:9000;
                fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
                fastcgi_index index.php;
                fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
                fastcgi_param PHP_VALUE "short_open_tag = On";
                include fastcgi_params;

                sendfile                        on;
                tcp_nopush                      off;
                keepalive_requests              0;
        }

        location /static_html {
                try_files \$uri \$uri/ /index.php?/\$request_uri;
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
}
EOT


service nginx reload || service nginx start
