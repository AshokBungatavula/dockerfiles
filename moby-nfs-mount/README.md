A Simple Docker image to automate mounting a remote NFS share into the Docker host.

### Usage
```
docker run -d \
    --privileged --pid=host \
    --restart=unless-stopped \
    -e SERVER=NFS_SERVER:/  \
    -e MOUNT=/host/mount/folder vipconsult/moby-nfs-mount
```
- SERVER : the remote NFS server 
- MOUNT : local host folder used for the mounting

and then to use it inside a container
```
  docker run -v /host/mount/folder:/container/folder
```
It support all Docker platforms that use the Moby Linux.<br>
  - Docker for Mac<br>
  - Docker for AWS<br/>
  - Docker for Windows (unsure)<br/>

### Here is how it works:<br/>
  nsenter to access the host namespace<br>
  install the nfs client on the host<br>
  mount the NFS on the hostusing the -e MOUNT env from the run command<br>

### This technique can be used in a swarm for persistant storage.
docker service create doesn't support --privileged and  --pid=host so we can use
```
swarm-exec \
    docker run -d \
    --privileged --pid=host \
    --restart=unless-stopped \
    -e SERVER=NFS_SERVER:/  \
    -e MOUNT=/host/mount/folder vipconsult/moby-nfs-mount 
```

https://github.com/mavenugo/swarm-exec

### NOTES: 
  this technique will be replaced by distributed docker  volumes plugins and automated docker plugin installation

### TO DO :Demo video

