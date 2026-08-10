FROM nginx:1.29-alpine

# Refresh fixable Alpine runtime packages before copying the static UI. The
# Trivy gate remains authoritative and will fail if HIGH/CRITICAL findings stay.
RUN apk upgrade --no-cache

COPY hackathon/ui/nginx.conf /etc/nginx/conf.d/default.conf
COPY hackathon/ui/index.html /usr/share/nginx/html/index.html
EXPOSE 8080
