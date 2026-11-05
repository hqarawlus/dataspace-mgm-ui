#################################################################################
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License, Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# SPDX-License-Identifier: Apache-2.0
#################################################################################

# Container image of the Eclipse Tractus-X Dataspace Management UI.
# One Dockerfile for every app of the workspace; APP selects the app (default: portal).
# Build:  docker build --build-arg APP=portal -t tractusx/dataspace-mgm-ui:local .
# Run:    docker run --rm -p 8080:8080 --read-only --tmpfs /tmp \
#           -v "$PWD/config.json:/usr/share/nginx/html/config/config.json:ro" tractusx/dataspace-mgm-ui:local
# Notice for the image on DockerHub: DOCKER_NOTICE.md (TRG 4.06)

ARG APP=portal

# ---- Build stage ----
FROM node:24-alpine AS build
ARG APP
WORKDIR /workspace
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY . .
RUN npx nx build "${APP}" --configuration=production \
    && mkdir -p /out \
    && cp -R "dist/apps/${APP}/." /out/

# ---- Runtime stage: nginx-unprivileged, as-is (TRG 4.02); runs as user 101 (TRG 4.03) ----
FROM nginxinc/nginx-unprivileged:1.31-alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /out /usr/share/nginx/html
# config.json is mounted at runtime into /usr/share/nginx/html/config, never baked in
USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
CMD ["nginx", "-g", "daemon off;"]
