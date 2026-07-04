FROM node:22-alpine

WORKDIR /app
COPY server.mjs /app/server.mjs

ENV PORT=8731
ENV DATA_DIR=/data
EXPOSE 8731

CMD ["node", "/app/server.mjs"]
