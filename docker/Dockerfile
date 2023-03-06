FROM nginx:latest

SHELL ["/bin/bash", "-c"]

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d
COPY proxy_params /etc/nginx

RUN apt-get update && apt-get install -y apt-transport-https
RUN apt-get install -y --no-install-recommends certbot python3-certbot-nginx