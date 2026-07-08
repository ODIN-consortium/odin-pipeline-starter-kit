# Security Policy

## Reporting a vulnerability

ODIN is provided as-is, without warranty or guaranteed support. Responses and fixes are
not guaranteed, so the most reliable protection is to run ODIN only in a trusted
environment, as described below.

This repository packages demo data and a Docker Compose stack that runs the ODIN
application from prebuilt images; the application source code lives in the main ODIN
project. If you do find a security issue, you may report it privately through GitHub's
private vulnerability reporting — use the
[ODIN-consortium organisation](https://github.com/ODIN-consortium) for issues in the
application, or the **Security** tab of this repository for issues specific to the demo
(data, compose, setup scripts). Please include enough detail to reproduce it.

## Deployment security model — read before deploying

**ODIN is designed to run on a single trusted machine (or a fully trusted network).
It must not be exposed to untrusted networks or untrusted local users.** Two properties
of the design make this non-negotiable:

### 1. Authentication is optional (enabled by default in this demo)

Setting `ODIN_AUTH_USER` and `ODIN_AUTH_PASSWORD` enables HTTP Basic Auth across the whole
app — both the frontend (UI + the `/api/` proxy) and the backend API enforce the same
credentials. This demo's `setup.sh` generates a unique username and password into `.env`, so
the login is on by default and you are prompted when you open the UI. If you clear those
values, the app runs unauthenticated and anyone who can reach it can register and delete
metadata, change settings, and launch or cancel pipeline runs.

### 2. The application has host Docker access

To run Nextflow pipelines, the API container mounts the **host Docker socket**
(`/var/run/docker.sock`) and launches pipeline tool containers as siblings on the host
daemon (the "Docker-outside-of-Docker" pattern). Anything that can drive that socket can
create a container that mounts the host filesystem — which is equivalent to **root on the
host**.

Combined, these mean that reaching the application over the network is effectively root
access to the host.

### How this demo exposes the application

In this demo's `docker-compose.yml`:

- The API container (`odin-app-api`) publishes **no** host port — it is reachable only
  from inside the Compose network.
- The frontend container (`odin-app-client`) is bound to **loopback**
  (`127.0.0.1:80:80`), and its nginx proxies `/api/` to the API container internally.

This means the web UI — and through its `/api/` proxy, the backend — is reachable only from
**this machine** (`http://localhost`), and with the default credentials from `setup.sh` it
also requires a login. That is the intended configuration: loopback binding *and* HTTP Basic
Auth.

> **Note:** The Enlighten visualisation services (`enlweb-client`, `enlweb-api`, ports 8080
> and 8081) are also bound to loopback, so the entire stack is reachable only from this
> machine.

### Recommendations for operators

- **Keep the login enabled** — `setup.sh` sets `ODIN_AUTH_USER` / `ODIN_AUTH_PASSWORD` in
  `.env`. Basic Auth sends the credential in effectively cleartext, so if you ever expose the
  demo beyond loopback, terminate TLS in front of it as well.
- **Keep the frontend bound to loopback** (the default). Change it to `80:80` (all
  interfaces) only on a fully trusted network, and understand that doing so exposes the app
  — and, past the login, host root — to every host that can reach port 80.
- **Do not run the demo on a shared or multi-user machine** where untrusted local users
  have accounts — a local user who can reach the UI has the same power as a remote one.
- **To reduce (not eliminate) the Docker-socket blast radius**, consider a filtered socket
  proxy (e.g. Tecnativa `docker-socket-proxy`) allowing only the container lifecycle calls
  Nextflow needs. Because such a proxy filters by API endpoint and not by request body, it
  cannot prevent a permitted `create container` call from bind-mounting the host — so it is
  hardening, not a fix.

## Known limitations

These are accepted trade-offs of the current single-machine design, not undisclosed bugs:

- Authentication is off unless configured; this demo enables it by default via `setup.sh`,
  with both the frontend and the backend API enforcing HTTP Basic Auth.
- Host Docker socket access (host-root-equivalent for anything that reaches the API).
- Intended for trusted, single-operator deployments only.
