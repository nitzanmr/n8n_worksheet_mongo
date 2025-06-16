# Flutter Frontend Dockerfile
# Multi-stage build for Flutter web app

# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:3.19.6 AS build

# Create a non-root user first
RUN useradd -m -u 1000 flutter

# Fix Flutter SDK permissions and ownership
RUN chown -R flutter:flutter /sdks/flutter && \
    chmod -R 755 /sdks/flutter && \
    git config --global --add safe.directory /sdks/flutter

# Switch to flutter user early to initialize Flutter
USER flutter

# Initialize Flutter (this creates cache directories with proper ownership)
RUN flutter config --no-analytics && \
    flutter doctor

# Set working directory and ensure flutter user owns it
WORKDIR /home/flutter/app
USER root
RUN chown -R flutter:flutter /home/flutter/app
USER flutter

# Copy pubspec files
COPY --chown=flutter:flutter pubspec.* ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY --chown=flutter:flutter . .

# Create web directory and index.html if it doesn't exist
RUN mkdir -p web && \
    if [ ! -f web/index.html ]; then \
        echo '<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Worksheet Viewer</title><meta name="viewport" content="width=device-width, initial-scale=1.0"><link rel="icon" type="image/png" href="favicon.png"/></head><body><script src="main.dart.js" type="application/javascript"></script></body></html>' > web/index.html; \
    fi

# Build web app
RUN flutter build web --release --web-renderer canvaskit

# Stage 2: Serve the built app with nginx
FROM nginx:alpine

# Copy built web app from build stage
COPY --from=build /home/flutter/app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files \$uri \$uri/ /index.html;
        
        # Enable compression
        gzip on;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create non-root user (nginx group already exists)
RUN adduser -S -u 1001 -G nginx appuser

# Change ownership
RUN chown -R appuser:nginx /usr/share/nginx/html
RUN chown -R appuser:nginx /var/cache/nginx
RUN chown -R appuser:nginx /var/log/nginx
RUN chown -R appuser:nginx /etc/nginx/conf.d
RUN touch /var/run/nginx.pid
RUN chown -R appuser:nginx /var/run/nginx.pid

USER appuser

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]