# Client machine must have devpi-client installed

# Establish connection to devpi server
devpi use http://localhost:3141

# Create a new user
devpi user -c raft password=test

# Login to the user
devpi login raft --password=test

# Create a new index (cannot upload directly to root/pypi)
devpi index -c dev bases=root/pypi

# Use the new index
devpi use raft/dev

# Upload the packages
devpi upload packages/*



# To install packages from this index
# pip install --index-url http://localhost:3141/raft/dev/+simple/ --trusted-host localhost minio==7.2.8
# OR
# export PIP_INDEX_URL=http://localhost:3141/raft/dev/+simple/
# export PIP_TRUSTED_HOST=localhost
# pip install minio==7.2.8