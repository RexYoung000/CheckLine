FROM node:24-alpine
WORKDIR /app
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src
COPY --chown=node:node review ./review
USER node
ENV BIND_ADDRESS=0.0.0.0 PORT=8787
EXPOSE 8787
CMD ["node", "src/server.mjs"]
