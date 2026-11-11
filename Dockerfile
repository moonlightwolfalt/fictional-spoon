# Era selector: builds public/ with Node, then serves it with nginx.
#
#   docker build -t era-selector .
#   docker run --rm -p 8080:8080 era-selector      # http://localhost:8080
#
# Sevalla sets PORT for the web process; nginx listens on it (default 8080).

FROM node:22-alpine AS build
WORKDIR /src
COPY package.json ./
COPY scripts ./scripts
COPY index.html eras-manifest.json ./
COPY mope_fixed_20170704 ./mope_fixed_20170704
COPY mope_fixed_20181111 ./mope_fixed_20181111
COPY mope_fixed_20191029 ./mope_fixed_20191029
COPY mope_fixed_20200321 ./mope_fixed_20200321
RUN npm run build

FROM nginx:1.27-alpine
ENV PORT=8080
# The official image renders /etc/nginx/templates/*.template with envsubst at start-up.
COPY deploy/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /src/public /usr/share/nginx/html
EXPOSE 8080
