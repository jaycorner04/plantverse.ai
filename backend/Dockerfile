FROM node:22-alpine

ENV NODE_ENV=production
ENV PORT=8787

WORKDIR /app

COPY package.json ./
COPY server.mjs ./

EXPOSE 8787

CMD ["node", "server.mjs"]
