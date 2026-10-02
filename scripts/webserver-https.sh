sudo apt update && sudo apt install -y apache2 openssl openssh-server
sudo openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
  -keyout /etc/ssl/private/webserver.key \
  -out /etc/ssl/certs/webserver.crt \
  -subj "/C=DO/ST=SantoDomingo/L=SantoDomingo/O=ITLA/CN=20.25.30.131" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
  -addext "subjectAltName=IP:20.25.30.131,IP:203.0.113.4"
sudo a2enmod ssl
# apuntar SSLCertificateFile / SSLCertificateKeyFile a los archivos generados en default-ssl.conf
sudo a2ensite default-ssl
sudo systemctl restart apache2
sudo systemctl enable --now ssh
