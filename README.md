# up_ocsp
用的免费证书，但是ocsp验证的是比较慢，导致客户端访问的时候3秒超时或者白页，脚本用于生成ocsp缓存，放在nginx上面，客户端验证的时候直接在nginx上验证，不需要到根证书验证。

# 方法
```
certbot-1.10.1以前的证书
sh /newdata/html/ssl/update_ssl_oscp.sh file1.goodid.com /etc/letsencrypt/live/file1.goodid.com/fullchain.pem "Let's_Encrypt" 

certbot-1.10.1以后的证书
sh /newdata/html/ssl/update_ssl_oscp.sh file1.goodid.com /etc/letsencrypt/live/file1.goodid.com/fullchain.pem "Let's_Encrypt_R3" 

```

# /etc/nginx/ocsp.conf
```
ssl_session_cache shared:SSL:10m;
ssl_session_tickets on;
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-
RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:
!PSK:!RC4;
ssl_stapling on;
ssl_stapling_file /newdata/html/ssl/file1.goodid.com/ocsp.resp;
ssl_stapling_verify on;
ssl_trusted_certificate /newdata/html/ssl/file1.goodid.com/checkid.pem;
resolver 8.8.8.8 valid=300s;
resolver_timeout 2s;

```

# /etc/nginx/www/web.conf

```
include ocsp.conf;
```