FROM barichello/godot-ci:4.7.2 AS build
WORKDIR /project
COPY . /project
RUN mkdir -p build/web && godot --headless --path /project --editor --quit --verbose
RUN godot --headless --path /project --export-release Web /project/build/web/index.html

FROM nginx:alpine
COPY --from=build /project/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
