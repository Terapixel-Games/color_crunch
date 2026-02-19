FROM python:3.12-slim

ENV PORT=8080
ENV DB_PATH=/data/terapixel-platform.db
ENV TPX_GAME_ID=color_crunch
ENV INTERNAL_SERVICE_KEY=ci-internal-key

WORKDIR /app

COPY backend/ci/terapixel-platform/app.py /app/app.py

RUN mkdir -p /data

EXPOSE 8080

CMD ["python", "/app/app.py"]
