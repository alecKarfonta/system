

# Status
juju status

# Watch status 
juju status --watch 5s

# Watch in color
watch -c juju status --color


# Watch pods starting up
watch microk8s kubectl get pods -n kubeflow

# Show Controller
juju show-controller


# Stop Kubeflow
juju destroy-model kubeflow --destroy-storage

# If that doesn't work
juju destroy-model kubeflow --destroy-storage --force


# Show controllers
juju controllers

# Switch containers
juju switch [CONTAINER_NAME]
