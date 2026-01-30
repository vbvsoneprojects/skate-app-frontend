# 🚀 ESTRATEGIA "PRE-BUILT" (Ligera para Render Starter)
# Ya no compilamos aquí (ahorra 2GB de RAM). Solo servimos lo que subiste.

FROM nginx:alpine

# Copiar configuración de Nginx (Puerto 8080)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiar la carpeta "build/web" que subiste al repo
COPY build/web /usr/share/nginx/html

# Exponer el puerto correcto
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
