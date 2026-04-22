FROM python:3.12-slim

RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /opt/program

RUN uv pip install --system fastapi gunicorn "uvicorn[standard]"

COPY app.py .
COPY routes.py .
COPY services.py .
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8000

CMD ["sh", "-c", "gunicorn app:app --workers 3 --worker-class uvicorn.workers.UvicornWorker --bind unix:/tmp/uvicorn.sock & until [ -S /tmp/uvicorn.sock ]; do sleep 0.1; done; exec nginx"]
