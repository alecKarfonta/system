# Create config
jupyter notebook --generate-config

# Generate password hash
jupyter notebook password

# Show password hash
cat  /root/.jupyter/jupyter_notebook_config.json

# Run notebook server
jupyter notebook --ip=0.0.0.0 --allow-root --no-browser