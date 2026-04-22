FROM python:3.12-slim

RUN apt-get update && apt-get install -y nginx && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /opt/program

RUN uv pip install --system flask gunicorn

COPY app.py .
COPY routes.py .
COPY services.py .
COPY wsgi.py .
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 5000

CMD ["sh", "-c", "gunicorn --bind unix:/tmp/gunicorn.sock --workers 3 wsgi:app & until [ -S /tmp/gunicorn.sock ]; do sleep 0.1; done; exec nginx"]
