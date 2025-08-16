# Traefik Docker

Zero‑hassle Traefik + Docker HTTPS setup for local and dev domains

## Setup

### Clone the repository

```bash
$ git clone https://github.com/ronangr1/traefik-docker.git ~/.docker/traefik-docker
$ cd ~/.docker/traefik-docker
```

### Prerequisites

```bash
$ sudo apt install -y docker-ce # or use orbstack
$ sudo apt install -y mkcert # brew install mkcert
```

Tip: Docker 20.10+ is required to use the new `docker compose` command.

### Export uid and gid (optional)

Add the following lines to your .bashrc or .zshrc file

```bash
export UID=$(id -u) 
export GID=$(id -g)
```

### Create self-signed certificates

You will need to create self-signed certificates in order to override your favorite browser's warnings.

```bash
$ chmod +x init.sh
$ ./init.sh
```

### Create the containers

Run the following command:

```bash
$ docker compose up -d
# Check the logs to see if everything is working
$ docker compose logs -f
```

### Link your project to Traefik

The first step is to replace the labels of the services that need to pass through the reverse proxy.

```bash
$ cd /path/to/your/project
$ cp .env.dist .env # or create a .env file
$ code .env # or any other editor
```

You must define your project's environment variables in the .env file at the root of your project. These are used to store credentials, ports and so on.

#### Edit the compose.yaml file

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=proxy"
      - "traefik.http.routers.${PROJECT_NAME}:-default}.rule=Host(`${PROJECT_NAME}:-default}.domain.localhost`)"
      - "traefik.http.routers.${PROJECT_NAME}:-default}.entrypoints=websecure"
      - "traefik.http.routers.${PROJECT_NAME}:-default}.tls=true"
    networks:
      - proxy
```

The load balancer port is set according to the application running: 80 for applications using a web server, 9000 for those using nodejs or similar.

#### Define the networks

```yaml
networks:
  proxy:
    external: true
  default:
```

The default network is defined so that your project's internal services can interconnect. You must therefore add this network to each service which needs to be reached by the other ones.

## Troubleshooting

You may experience a Bad Gateway issue when trying to access your local applications.

Run the command below to solve the problem

```bash
$ docker network connect proxy traefik
$ docker network connect proxy mailhog
```

## Maintainers

* Ronan Guérin - *Maintener*

## Support

Raise a new [request](https://github.com/ronangr1/traefik-docker/issues) to the issue tracker.
