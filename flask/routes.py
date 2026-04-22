import logging
from flask import Blueprint, request, jsonify
from services import predict

logger = logging.getLogger(__name__)

bp = Blueprint("main", __name__)


@bp.route("/", methods=["GET"])
def index():
    return jsonify({"service": "tinymlapi", "framework": "flask", "endpoints": ["/health", "/invocations"]}), 200


@bp.route("/health", methods=["GET"])
def health():
    logger.info("GET /health")
    response = {"status": "ok"}
    logger.info("Response: %s", response)
    return jsonify(response), 200


@bp.route("/invocations", methods=["POST"])
def invocations():
    data = request.get_json()
    logger.info("POST /invocations - payload: %s", data)

    if not data or "min_val" not in data or "max_val" not in data:
        error = {"error": "Invalid JSON format. 'min_val' and 'max_val' are required."}
        logger.warning("Invalid payload: %s", error)
        return jsonify(error), 400

    if data["min_val"] > data["max_val"]:
        error = {"error": "'min_val' must be less than or equal to 'max_val'."}
        logger.warning("Invalid payload: %s", error)
        return jsonify(error), 400

    result = predict(data["min_val"], data["max_val"])
    logger.info("Response: %s", result)
    return jsonify(result), 200
