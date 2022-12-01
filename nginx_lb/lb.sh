#!/bin/bash
sudo yum install -y gcc gcc-c++ git
sudo yum install httpd-tools iptables-services -y

cd /home/vagrant
wget http://nginx.org/download/nginx-1.20.0.tar.gz 
tar -zxf /home/vagrant/nginx-1.20.0.tar.gz
wget https://sourceforge.net/projects/pcre/files/pcre/8.44/pcre-8.44.tar.gz 
tar -zxf /home/vagrant/pcre-8.44.tar.gz
wget https://github.com/openssl/openssl/archive/refs/tags/OpenSSL_1_0_2j.tar.gz 
tar -zxf /home/vagrant/OpenSSL_1_0_2j.tar.gz 
wget https://github.com/vozlt/nginx-module-vts/archive/refs/tags/v0.1.18.tar.gz 
tar -zxf /home/vagrant/v0.1.18.tar.gz
rm -rf *.tar.gz

mkdir /home/vagrant/nginx 
cd nginx-1.20.0
./configure --prefix=/home/vagrant/nginx \
            --sbin-path=/home/vagrant/nginx/sbin/nginx \
            --conf-path=/home/vagrant/nginx/conf/nginx.conf \
            --error-log-path=/home/vagrant/nginx/logs/error.log \
            --http-log-path=/home/vagrant/nginx/logs/access.log \
            --pid-path=/home/vagrant/nginx/logs/nginx.pid \
            --user=vagrant \
            --group=vagrant \
            --with-http_ssl_module \
            --with-http_realip_module \
            --without-http_gzip_module \
            --with-pcre=../pcre-8.44 \
            --with-openssl=../openssl-OpenSSL_1_0_2j \
            --add-dynamic-module=../nginx-module-vts-0.1.18
make && make install
cd ..

cat << EOF > /home/vagrant/nginx.service
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
User=vagrant
Group=vagrant
Type=forking
PIDFile=/home/vagrant/nginx/logs/nginx.pid
ExecStartPre=/home/vagrant/nginx/sbin/nginx -t
ExecStart=/home/vagrant/nginx/sbin/nginx
ExecReload=/home/vagrant/nginx/sbin/nginx -s reload
ExecStop=/home/vagrant/nginx/sbin/nginx -s stop

[Install]
WantedBy=multi-user.target
EOF

sudo mv /home/vagrant/nginx.service /etc/systemd/system/nginx.service
tar -zxf /vagrant/html.tar.gz -C /home/vagrant/nginx/
sudo cp /vagrant/err.html /home/vagrant/nginx/html/
mkdir -p /home/vagrant/nginx/conf/vhosts

cat << EOF > /home/vagrant/nginx/conf/nginx.conf
user  vagrant vagrant;
worker_processes  1;

load_module modules/ngx_http_vhost_traffic_status_module.so;

events {
    worker_connections  1024;
}

http {
    include         mime.types;
    default_type    application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    vhost_traffic_status_zone;
    include /home/vagrant/nginx/conf/vhosts/lb.conf;
}
EOF
    
cat << EOF > /home/vagrant/nginx/conf/vhosts/web.conf;
upstream backend {
    server 192.168.56.10:8080 weight=1;
    server 192.168.56.20:8080 weight=3;
}
EOF

cat << EOF > /home/vagrant/nginx/conf/vhosts/lb.conf;
    include /home/vagrant/nginx/conf/vhosts/web.conf;

    server {
        listen 8080;
        server_name  192.168.56.30;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen       8443  ssl;
        server_name  192.168.56.30;
        ssl_certificate      /home/vagrant/nginx/conf/server.crt;
        ssl_certificate_key  /home/vagrant/nginx/conf/server.key;

        location / {
            proxy_redirect off;
            proxy_pass http://backend;
            proxy_set_header Host \$host;
        }

        location ~* /status {
            allow   192.168.56.1;
            deny    all;
            vhost_traffic_status on; 
            vhost_traffic_status_display;
            vhost_traffic_status_display_format html;
        }

        proxy_intercept_errors on;
        error_page 404 /err.html;
        location = /err.html {
            root    html;
        }

    }
EOF

htpasswd -b -c /home/vagrant/nginx/conf/.htpasswd admin nginx

cd nginx/conf
openssl req -nodes -x509 -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/C=BY/ST=Minsk/L=Minsk/O=EPAM/OU=DevOps Lab/CN=nginx"
sudo chmod 600 server.key
sudo chmod 600 server.crt
cd
sudo chown -R vagrant:vagrant /home/vagrant/nginx

sudo systemctl enable firewalld
sudo systemctl start firewalld

sudo firewall-cmd --add-port=8080/tcp
sudo firewall-cmd --add-forward-port=port=80:proto=tcp:toport=8080
sudo firewall-cmd --add-port=8443/tcp
sudo firewall-cmd --add-forward-port=port=443:proto=tcp:toport=8443

sudo firewall-cmd --runtime-to-permanent
sudo firewall-cmd --reload

sudo systemctl enable nginx
sudo systemctl start nginx
