# AirDC++ Web Client Docker image

Docker image running [AirDC++ Webclient software][airdcpp-github].
You must have proper knowledge of [Docker] to use this image.

## Run the application

Make sure all the environment variables and volumes in `docker-compose.yaml` fit you deployment.


    docker-compose build && docker-compose up -d

The web UI will be available on <http://localhost> and <https://localhost>.
HTTPS is using self-signed certs, see [Enable HTTPS] for more details.

> Username / password for the default admin account is: `admin` / `password`

> The SMB share will be mounted in `/mnt/smb-share`

> PUID / PGID environment variables are only available using the `latest`
> tag and versions later than 2.11.0. Older images will *not* be rebuilt.

### Environment variables

If you run the container as root you need to set the PUID/PGID variables.
Example: `-e PUID=1000 -e PGID=1000`.
All files written by the application will be owned by this user and group.
Use UMASK to change the permissions of the files.

- `PUID`

  Application runs as this user id.
  Usually you want this to be your local user id. 

- `PGID`

  Application runs as this group id.
  Usually you want this to be your local user's group id. 

> The reason for the >= 101 limitation is that the image already contains
> accounts and groups with IDs lower than that. Use `--user` if you need to
> use IDs lower than 101.

- `UMASK`

  Changes how the application writes its files. Defaults to 0022.
  Read more on the [umask man page][umask].



## docker-compose

There is a docker-compose file available to set up the application as a
service on a docker host. Just run the following.

    docker-compose up -d

### Compose variables

You can configure some aspects of the application when using docker-compose
by setting these environment variables before running `docker-compose up -d`.

- `PUID`

  Application runs as this user id. Defaults to 1000.
  Usually you want this to be your local user id. **Must be >= 101.**

- `PGID`

  Application runs as this group id. Defaults to 1000.
  Usually you want this to be your local user's group id. **Must be >= 101.**

> The reason for the >= 101 limitation is that the image already contains
> accounts and groups with IDs lower than that. Use `--user` if you need to
> use IDs lower than 101.


- `UMASK`

  Changes how the application writes its files. Defaults to 0022.
  Read more on the [umask man page][umask].

- `SMB_HOST` **(required)**
  Hostname of the SMB share

- `SMB_SHARE` **(required)**
  Share name of the SMB share

- `SMB_USERNAME` **(required)**
  Username of user with access to the SMB share

- `SMB_PASSWORD` **(required)**
  Password for `SMB_USERNAME`

- `HTTP_PORT`

  Published HTTP port. Defaults to 80.

- `HTTPS_PORT`

  Published HTTPS port. Defaults to 443.

- `TCP_PORT`

  Published TCP port for incoming connections. Defaults to 21248.
  If this is changed you have to change it in the application settings as well.

- `UDP_PORT`

  Published UDP port for incoming connections. Defaults to 21248.
  If this is changed you have to change it in the application settings as well.

- `TLS_PORT`

  Published TLS port for incoming connections. Defaults to 21249.
  If this is changed you have to change it in the application settings as well.

## Volumes

- `/.airdcpp`

  This volume stores the application settings.

  On launch it will be populated with default settings unless the folder
  already contains the DCPlusPlus.xml configuration file.

- `/Downloads`

  This is the default Download folder, but you can change this in the
  settings through the web UI.

- `/Share`

  This is the default share folder.

  Any bind mounted folder under this will automatically be added to your Share.

## Exposed Ports

- `5600` HTTP port

- `5601` HTTPS port

- `21248` TCP and UDP port for incoming connections. You have to publish this
  on the same port number otherwise clients will not be able to connect.

- `21249` TCP port for incoming encrypted connections. You have to publish this
  on the same port number otherwise clients will not be able to connect.

If you want to use other ports for incoming connections you can change them
under Settings>Connectivity>Advanced>Ports in the web UI.

The incoming connection ports are used to enable *active mode*. This allows
you to connect to all peers in a hub, including the ones in *passive mode*.

Read more about connectivity modes in the [official FAQ][conn_faq].

## Add/modify admin users

To add/modify *administrative* users, run the following commands. Admin users
can then add normal users in the web UI under Settings > System > Users.

    docker stop airdcpp-smb
    docker run --rm -it --volumes-from airdcpp-smb \
        -e PUID=$(id -u) -e PGID=$(id -g) \
        gangefors/airdcpp-webclient --add-user
    docker start airdcpp-smb

> You must stop the webclient application container before running the
> `--add-user` command. If you add a user while it's running, the
> configuration will be overwritten when the application shuts down.

## Upgrade

- Pull the latest image.
- Stop and remove the container.
- Start a new container with the same command you started the old one.

Example:

    docker pull gangefors/docker-airdcpp-webclient
    docker stop airdcpp-container
    docker rm airdcpp-container
    docker run -d --name airdcpp-container \
        -p 80:5600 -p 443:5601 \
        -p 21248:21248 -p 21248:21248/udp -p 21249:21249 \
        -e PUID=$(id -u) \
        -e PGID=$(id -g) \
        -v airdcpp-volume:/.airdcpp \
        -v $HOME/Downloads:/Downloads \
        -v $HOME/Share:/Share \
        gangefors/airdcpp-webclient

## Enable HTTPS

The image comes with self-signed certificates so you should be able to use
HTTPS out of the box. But if you want to generate your own certificates here's
how you do it.

> The container must be running.

    docker exec -it airdcpp-container openssl req \
        -subj "/C=US/ST=State/L=City/O=/CN=localhost" \
        -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /.airdcpp/Certificates/client.key \
        -out /.airdcpp/Certificates/client.crt

Change the CN string to whatever the domain name or IP you are running your
service on. You can also add more information in the -subj string if you want.
Check [this site][certs] for more information on the different fields.

## Troubleshooting

### File permission issues

If you get any permission issues with the config files you can solve this by
running a temporary container and `chown`ing the files through that.

    docker run --rm \
      --volumes-from=airdcpp-container \
      debian:stable-slim \
      chown -R $(id -u):$(id -g) /.airdcpp

### Container isn't working with Podman

It might happen that the startup script doesn't correctly identify that it
was podman that started the container. This can be fixed by adding
`container=podman` environment variable when starting the container.

    podman run ... -e container=podman ...

### Enable entrypoint logging

To see what commands are run during startup of the container you can add the
following environment variable.

- `LOG_STARTUP`

  Enable verbose logging during startup.
  Defaults to empty string, any value will enable verbose logging.

  `docker run ... -e LOG_STARTUP=1 ...`

### Enable communication debug logs

AirDC++ have some options for enabling communication debug logs. Just add them
as normal program options after the image name.

    --cdm-hub
      Print all protocol communication with hubs in the console
    --cdm-client
      Print all protocol communication with other clients in the console
    --cdm-web
      Print web API commands and file requests in the console

## Building the Docker image

> This is not needed since the images are already pushed to Docker hub.

If you want to build your own image run the following command.

    docker build --no-cache --pull -t gangefors/airdcpp-webclient:latest .

The Dockerfile is set up to fetch the latest version on master branch in the
[airdcpp-webclient git repo][airdcpp-github].

### Build a different version

To build a different version than `latest` supply the build-arg `dl_url`.
Find the URL for the version you want to build at <https://web-builds.airdcpp.net/stable/>

    export dl_url="https://web-builds.airdcpp.net/stable/airdcpp_2.7.0_webui-2.7.0_64-bit_portable.tar.gz"
    docker build --no-cache --pull -t gangefors/airdcpp-webclient:2.7.0 --build-arg dl_url .

[.airdcpp]: .airdcpp
[airdcpp-github]: https://github.com/airdcpp-web/airdcpp-webclient
[bindmount]: https://docs.docker.com/storage/bind-mounts/#mount-into-a-non-empty-directory-on-the-container
[certs]: http://www.shellhacks.com/en/HowTo-Create-CSR-using-OpenSSL-Without-Prompt-Non-Interactive
[conn_faq]: http://dcplusplus.sourceforge.net/webhelp/faq_connection.html
[docker]: https://docs.docker.com/learn/
[Exposed Ports]: #exposed-ports
[Enable HTTPS]: #enable-https
[umask]: https://man7.org/linux/man-pages/man2/umask.2.html
