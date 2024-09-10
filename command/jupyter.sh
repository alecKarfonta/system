# Create config
jupyter notebook --generate-config

# Generate password hash
jupyter notebook password

# Show password hash
cat  /root/.jupyter/jupyter_notebook_config.json

cat /root/.jupyter/jupyter_server_config.json



# Set options for certfile, ip, password, and toggle off
# browser auto-opening
#c.NotebookApp.certfile = u'/app/mycert.pem'
#c.NotebookApp.keyfile = u'/app/mycert.pem'
# Set ip to '*' to bind on all interfaces (ips) for the public server
c.NotebookApp.ip = '*'
c.NotebookApp.password = u''
c.NotebookApp.open_browser = False

# It is a good idea to set a known, fixed port for server access
c.NotebookApp.port = 8888

sudo nano /root/.jupyter/jupyter_notebook_config.py




# Run notebook server
jupyter notebook --ip=0.0.0.0 --allow-root --no-browser