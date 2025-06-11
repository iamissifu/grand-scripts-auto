
#!/bin/bash

TOMCAT_DIR=/opt/tomcat
TOMCAT_SERVICE=tomcat

echo "[+] Configuring admin user for Tomcat..."

# Add admin and manager roles + user
sed -i '/<\/tomcat-users>/i \
<role rolename="admin-gui"/>\n\
<role rolename="manager-gui"/>\n\
<user username="admin" password="password" roles="admin-gui,manager-gui"/>' \
$TOMCAT_DIR/conf/tomcat-users.xml

echo "[+] Enabling remote access to Manager and Host Manager..."

# Remove RemoteAddrValve restrictions
for file in $TOMCAT_DIR/webapps/{manager,host-manager}/META-INF/context.xml; do
  if grep -q "RemoteAddrValve" "$file"; then
    sed -i '/<Valve className="org.apache.catalina.valves.RemoteAddrValve"/d' "$file"
    sed -i '/allow="127\.\d+\.\d+\.\d+\|::1"/d' "$file"
  fi
done

echo "[+] Restarting Tomcat service..."
systemctl restart $TOMCAT_SERVICE

echo "[✓] Tomcat configuration completed."
echo "[→] Access Tomcat: http://<your-ip>:8080"
echo "[→] Manager GUI: http://<your-ip>:8080/manager/html"
echo "[→] Login: admin / password"
