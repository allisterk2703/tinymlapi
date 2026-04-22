import logging
from flask import Flask
from routes import bp

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
)


def create_app():
    app = Flask(__name__)
    app.register_blueprint(bp)
    return app
