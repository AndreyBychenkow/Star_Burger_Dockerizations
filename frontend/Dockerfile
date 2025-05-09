FROM node:16.16.0-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

EXPOSE 1234

CMD ["npm", "start"]