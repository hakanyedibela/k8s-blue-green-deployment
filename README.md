# Blue Green Deployment in Kubernetes

This is a simple explaination of how to drive blue-green deployment in K8S.

## Steps to create a simple blue-green deployment

### 1. Create blue-green namespace

```Shell
kubectl create ns blue-green
```

### 2. Create blue-deploy.yaml

```Shell
kubectl apply -f blue-deploy.yaml
```

### 3. Expose blue-deploy deployment

```Shell
kubectl expose deploy blue-deploy -n blue-green --port=18080 --name=stable-svc 
```
Check if everything is running fine and test against the service endpoint of the deployment for example with temp busybox container

### 4. Create green-deploy deployment

```Shell
kubectl apply -f green-deploy.yaml
```

### 5. Expose a test svc 
Creating a test svc to test the green deployment. Like this the stable-svc in the previous step is still untouched.

```Shell
kubectl expose deploy green-deploy -n blue-green --port=18080 --name=test-svc 
```

Test also the new green deployment. If everthing is fine, delet it.

```Shell
kubectl delete svc test-svc -n blue-green
```

### 6. Replace blue deployment with green deployment
```Shell
kubectl delete svc stable-svc -n blue-green; kubectl expose deploy green-deploy -n blue-green --port=18080 --name=stable-svc
```

The deleted stable-svc have to be created again with the same name, but now for the green deployment. 