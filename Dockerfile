# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

# Descargar dependencias y compilar
# Usamos --obfuscate para seguridad y --release para performance
RUN flutter pub get
RUN flutter build web --release --obfuscate --split-debug-info=./debug-info

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copiar build output al directorio de Nginx
COPY --from=build /app/build/web /usr/share/nginx/html

# Copiar configuración custom de Nginx (para SPA routing)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponer puerto 80 (Render lo mapea automáticamente)
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
