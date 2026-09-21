@echo off
echo ========================================
echo   Market Darwaza - Web Deploy Script
echo ========================================
echo.

echo [1/4] Uploading files to server...
echo     (Enter password: 22karox22 when prompted)
echo.
scp -r "c:\Users\karox\Desktop\Krenakanm\market_darwaza\build\web\*" root@46.225.156.226:/var/www/marketdarwaza/
echo.

echo [2/4] Setting up Nginx...
echo     (Enter password again when prompted)
echo.
ssh root@46.225.156.226 "apt-get install -y nginx && cat > /etc/nginx/sites-available/marketdarwaza << 'NGINX_CONF' && server { listen 80; server_name marketdarwaza.duckdns.org; root /var/www/marketdarwaza; index index.html; location / { try_files $uri $uri/ /index.html; } } NGINX_CONF ln -sf /etc/nginx/sites-available/marketdarwaza /etc/nginx/sites-enabled/ && nginx -t && systemctl restart nginx"
echo.

echo [3/4] Done!
echo     Visit: http://marketdarwaza.duckdns.org
echo ========================================
pause
