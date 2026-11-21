#alpine is a tiny linux #nginx is a webserver (this is a small official nginx image)
FROM nginx:alpine

#Use our nginx setting so the app is server on port 3000
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the pre-built Vite/React files (the dist folder) into nginx's web root
COPY dist/ /usr/share/nginx/html/

#This make the ocntainer listen on port 3000
EXPOSE 3000

# Run Nginx in the foreground (not as a background daemon) so it remains the main process (PID 1).
# Docker stops the container when its main process exits, so running Nginx in the foreground is important to keep the container alive.
CMD ["nginx", "-g", "daemon off;"]

