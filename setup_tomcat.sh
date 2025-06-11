
#!/bin/bash

TOMCAT_VERSION=10.1.20
TOMCAT_USER=tomcat
INSTALL_DIR=/opt/tomcat
JAVA_HOME_PATH=/usr/lib/jvm/java-11-openjdk-amd64

echo "[+] Updating packages and installing Java..."
apt update && apt install -y default-jdk wget curl

echo "[+] Creating tomcat user..."
useradd -m -U -d $INSTALL_DIR -s /bin/false $TOMCAT_USER

echo "[+] Downloading Tomcat..."
cd /tmp
wget https://downloads.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz

echo "[+] Extracting Tomcat..."
mkdir -p $INSTALL_DIR
tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $INSTALL_DIR --strip-components=1

echo "[+] Setting permissions..."
chown -R $TOMCAT_USER: $INSTALL_DIR
chmod +x $INSTALL_DIR/bin/*.sh

echo "[+] Creating systemd service..."
cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=$TOMCAT_USER
Group=$TOMCAT_USER

Environment=JAVA_HOME=$JAVA_HOME_PATH
Environment=CATALINA_PID=$INSTALL_DIR/tomcat.pid
Environment=CATALINA_HOME=$INSTALL_DIR
Environment=CATALINA_BASE=$INSTALL_DIR
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=$INSTALL_DIR/bin/startup.sh
ExecStop=$INSTALL_DIR/bin/shutdown.sh
Restart=on-failure
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "[+] Reloading systemd and starting Tomcat..."
systemctl daemon-reload
systemctl enable --now tomcat

echo "[+] Tomcat is now running on http://localhost:8080"
echo "[+] You can access the Tomcat manager at http://localhost:8080/manager"
