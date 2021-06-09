FROM nginx:stable-alpine
RUN rm -rf /etc/nginx/conf.d
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf
COPY /landingpage/ /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]