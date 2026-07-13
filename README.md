![banner](https://raw.githubusercontent.com/11notes/static/refs/heads/master/img/banner/README.png)

# TALOSADMIN
![size](https://img.shields.io/badge/image_size-258MB-green?color=%2338ad2d)![5px](https://raw.githubusercontent.com/11notes/static/refs/heads/master/img/markdown/transparent5x2px.png)![pulls](https://img.shields.io/docker/pulls/11notes/talosadmin?color=2b75d6)![5px](https://raw.githubusercontent.com/11notes/static/refs/heads/master/img/markdown/transparent5x2px.png)[<img src="https://img.shields.io/github/issues/11notes/docker-talosadmin?color=7842f5">](https://github.com/11notes/docker-talosadmin/issues)![5px](https://raw.githubusercontent.com/11notes/static/refs/heads/master/img/markdown/transparent5x2px.png)![swiss_made](https://img.shields.io/badge/Swiss_Made-FFFFFF?labelColor=FF0000&logo=data:image/svg%2bxml;base64,PHN2ZyB2ZXJzaW9uPSIxIiB3aWR0aD0iNTEyIiBoZWlnaHQ9IjUxMiIgdmlld0JveD0iMCAwIDMyIDMyIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxyZWN0IHdpZHRoPSIzMiIgaGVpZ2h0PSIzMiIgZmlsbD0idHJhbnNwYXJlbnQiLz4KICA8cGF0aCBkPSJtMTMgNmg2djdoN3Y2aC03djdoLTZ2LTdoLTd2LTZoN3oiIGZpbGw9IiNmZmYiLz4KPC9zdmc+)

Container image to manage talos k8s clusters on vSphere

# SYNOPSIS 📖
**What can I do with this?** Talos admin image with tools ready for you to use. Does replace govc with custom version that can ingest the secrets file.

# COMPOSE ✂️
```yaml
name: "talos"

x-lockdown: &lockdown
  # prevents write access to the image itself
  read_only: true
  # prevents any process within the container to gain more privileges
  security_opt:
    - "no-new-privileges=true"

services:
  admin:
    image: "11notes/talosadmin:1.0.3"
    <<: *lockdown
    environment:
      TZ: "Europe/Zurich"
      GOVC_URL: "${GOVC_URL}"
      GOVC_USERNAME: "${GOVC_USERNAME}"
      GOVC_PASSWORD_FILE: "/run/secrets/password"
    volumes:
      - "talosadmin.var:/talosadmin"
    tmpfs:
      # needed for read-only
      - "/run/secrets:uid=1000,gid=1000"
      - "/tmp:uid=1000,gid=1000"
    secrets:
      - "password"
    networks:
      frontend:
    restart: "always"

volumes:
  talosadmin.var:

networks:
  frontend:

secrets:
  password:
    file: "./password.txt"
```
To find out how you can change the default UID/GID of this container image, consult the [RTFM](https://github.com/11notes/RTFM/blob/main/linux/container/image/11notes/how-to.changeUIDGID.md#change-uidgid-the-correct-way).

# DEFAULT SETTINGS 🗃️
| Parameter | Value | Description |
| --- | --- | --- |
| `user` | docker | user name |
| `uid` | 1000 | [user identifier](https://en.wikipedia.org/wiki/User_identifier) |
| `gid` | 1000 | [group identifier](https://en.wikipedia.org/wiki/Group_identifier) |
| `home` | /talosadmin | home directory of user docker |

# ENVIRONMENT 📝
| Parameter | Value | Default |
| --- | --- | --- |
| `TZ` | [Time Zone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) | |
| `DEBUG` | Will activate debug option for container image and app (if available) | |

# MAIN TAGS 🏷️
These are the main tags for the image. There is also a tag for each commit and its shorthand sha256 value.

* [1.0.3](https://hub.docker.com/r/11notes/talosadmin/tags?name=1.0.3)
* [latest](https://hub.docker.com/r/11notes/talosadmin/tags?name=latest)
* [1.0.3-unraid](https://hub.docker.com/r/11notes/talosadmin/tags?name=1.0.3-unraid)
* [latest-unraid](https://hub.docker.com/r/11notes/talosadmin/tags?name=latest-unraid)
* [1.0.3-nobody](https://hub.docker.com/r/11notes/talosadmin/tags?name=1.0.3-nobody)
* [latest-nobody](https://hub.docker.com/r/11notes/talosadmin/tags?name=latest-nobody)

# REGISTRIES ☁️
```
docker pull 11notes/talosadmin:1.0.3
docker pull ghcr.io/11notes/talosadmin:1.0.3
docker pull quay.io/11notes/talosadmin:1.0.3
```

# UNRAID VERSION 🟠
This image supports unraid by default. Simply add **-unraid** to any tag and the image will run as 99:100 instead of 1000:1000.

# NOBODY VERSION 👻
This image supports nobody by default. Simply add **-nobody** to any tag and the image will run as 65534:65534 instead of 1000:1000.

# SOURCE 💾
* [11notes/talosadmin](https://github.com/11notes/docker-talosadmin)

# PARENT IMAGE 🏛️
* [11notes/alpine:stable](https://hub.docker.com/r/11notes/alpine)

# BUILT WITH 🧰
* [talosctl](https://github.com/siderolabs/talos)
* [govc](https://github.com/vmware/govmomi)
* [kubectl](https://github.com/kubernetes/kubernetes)
* [11notes/util](https://github.com/11notes/docker-util)

# GENERAL TIPS 📌
> [!TIP]
>* Use a reverse proxy like Traefik, Nginx, HAproxy to terminate TLS and to protect your endpoints
>* Use Let’s Encrypt DNS-01 challenge to obtain valid SSL certificates for your services

# ElevenNotes™️
This image is provided to you at your own risk. Always make backups before updating an image to a different version. Check the [releases](https://github.com/11notes/docker-talosadmin/releases) for breaking changes. If you have any problems with using this image simply raise an [issue](https://github.com/11notes/docker-talosadmin/issues), thanks. If you have a question or inputs please create a new [discussion](https://github.com/11notes/docker-talosadmin/discussions) instead of an issue. You can find all my other repositories on [github](https://github.com/11notes?tab=repositories).

*created 13.07.2026, 14:16:19 (CET)*