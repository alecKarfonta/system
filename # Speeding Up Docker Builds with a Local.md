# Speeding Up Docker Builds with a Local devpi Pip Cache Server

When working with machine learning projects in Docker, you often find yourself dealing with large numbers of dependencies. This can significantly slow down your Docker build times, especially when you're iterating quickly or working in environments with limited internet bandwidth. A great solution to this problem is setting up a local devpi server to cache your pip packages. In this guide, we'll walk through the process of setting up a devpi server, configuring it to start automatically on boot, and modifying your Dockerfile to use this local cache.

## What is devpi?

devpi is a powerful PyPI-compatible server and packaging/testing/release tool. For our purposes, we'll be using it as a caching proxy for PyPI, which will store packages locally after they've been downloaded once, significantly speeding up subsequent installations.

## Setting Up the devpi Server

1. First, let's install devpi-server and devpi-web:

   ```bash
   pip install devpi-server devpi-web
   ```

2. Initialize the devpi-server:

   ```bash
   devpi-init
   ```

3. Start the devpi-server:

   ```bash
   devpi-server --start --host 0.0.0.0 --port 3141
   ```

   This command starts the server and makes it accessible on all network interfaces on port 3141.

4. Create a user and index:

   ```bash
   devpi use http://localhost:3141
   devpi user -c admin password=somepassword
   devpi login admin --password=somepassword
   devpi index -c dev
   devpi use admin/dev
   ```

   These commands create an admin user, a 'dev' index, and set it as the current index.

## Configuring devpi to Start on Boot

To ensure that your devpi server starts automatically when your system boots, we'll set up a systemd service.

1. Create a new systemd service file:

   ```bash
   sudo nano /etc/systemd/system/devpi.service
   ```

2. Add the following content to the file:

   ```
   [Unit]
   Description=devpi server
   After=network.target

   [Service]
   Type=simple
   User=your_username
   ExecStart=/usr/local/bin/devpi-server --host 0.0.0.0 --port 3141
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

   Replace `your_username` with the appropriate username.

3. Save the file and exit the editor.

4. Reload systemd, enable the service, and start it:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable devpi
   sudo systemctl start devpi
   ```

Now, your devpi server will start automatically on system boot.

## Configuring Docker to Use the devpi Server

To use your local devpi server in your Docker builds, you'll need to modify your Dockerfile and create a pip.conf file.

1. Create a pip.conf file in your project directory:

   ```
   [global]
   index-url = http://host.docker.internal:3141/root/pypi/+simple/
   trusted-host = host.docker.internal
   ```

   Note: `host.docker.internal` is a special DNS name in Docker for Windows and Mac that resolves to the host machine. For Linux, you might need to use the host's actual IP address.

2. Modify your Dockerfile to copy and use this pip.conf:

   ```dockerfile
   FROM python:3.8

   # Copy pip.conf into the Docker image
   COPY pip.conf /etc/pip.conf

   # Your other Dockerfile instructions...
   
   # Install requirements
   COPY requirements.txt .
   RUN pip install -r requirements.txt

   # Rest of your Dockerfile...
   ```

Now, when you build your Docker image, it will use your local devpi server as a package cache, significantly speeding up builds after the initial download of packages.


## Conclusion

By setting up a local devpi server, you can dramatically reduce the time it takes to build Docker images for your machine learning projects. This setup is particularly beneficial in environments where you frequently rebuild images or have limited internet bandwidth. Remember to periodically clean up your devpi cache to manage disk usage, especially if you're working with large machine learning libraries. Regularly monitoring your logs will help ensure smooth operation and quick resolution of any issues that may arise.