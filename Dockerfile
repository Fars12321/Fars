FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY index.html ./
EXPOSE 3000
CMD ["sh","-c","npx serve -s . -l ${PORT:-3000}"]
