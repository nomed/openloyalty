ARG NODE_IMAGE=node:6@sha256:92a780ce4191097a1470be20a40a590ac9601e53811c518effeb152ecd41548a
ARG NGINX_IMAGE=nginx:1.15@sha256:e770165fef9e36b990882a4083d8ccf5e29e469a8609bb6b2e3b47d9510e2c8d
FROM ${NODE_IMAGE} AS frontend
ARG APP_PATH
ARG API_URL
WORKDIR /src
COPY ${APP_PATH}/frontend/ ./
RUN npm install --prefix /opt/npm5 npm@5.10.0 --unsafe-perm
COPY runtime/web/frontend-package-lock.json ./package-lock.json
RUN node -e "const fs=require('fs');const p=require('./package.json');p.dependencies['angular-sanitize']='1.6.6';fs.writeFileSync('package.json',JSON.stringify(p,null,2)+'\\n')" \
    && /opt/npm5/node_modules/.bin/npm ci --unsafe-perm --no-audit --no-fund \
    && npm ls angular-sanitize
COPY runtime/web/frontend-config.js /tmp/frontend-config.js
RUN sed "s|__API_URL__|${API_URL}|g" /tmp/frontend-config.js > src/config.js \
    && npm run build

FROM ${NGINX_IMAGE}
ARG APP_PATH
COPY ${APP_PATH}/backend/web/ /var/www/openloyalty/web/
COPY --from=frontend /src/dist/ /var/www/openloyalty/frontend/
COPY runtime/web/nginx.conf /etc/nginx/conf.d/default.conf
