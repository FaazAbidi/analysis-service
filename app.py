from datetime import datetime
import json
from flask import Flask, jsonify, request, render_template
from tasks import process_with_r
from celery.result import AsyncResult
import os
import traceback
from flask_cors import CORS


app = Flask(__name__)
CORS(app)


@app.route("/", methods=["GET", "POST"])
def index():
    return render_template("index.html")


@app.route("/preprocess", methods=["POST"])
def preprocess():
    """
    Endpoint to preprocess data using R script.

    Expected JSON input format:
    {
        "method": "fix_missing",
        "taskMethodId": "213",
        "target": null,
        "columns": {
            "age": {
                "type":  "QUALITATIVE",
                "step": "impute_mean"
            }
        }
    }
    """
    try:
        # Get data from reques
        
        request_json = request.get_json()
        
        if not request_json:
            return jsonify({"error": "No data provided"}), 400
        
        print(f"request_json: {request_json}")
        
        method: str = request_json.get("method", None)
        task_method_id: int = request_json.get("taskMethodId", None)
        user_id: str = request_json.get("userId", None)
        
        if not method:
            return jsonify({"error": "method is required"}), 400
        
        if not task_method_id:
            return jsonify({"error": "taskMethodId is required"}), 400
        
        if not user_id:
            return jsonify({"error": "userId is required"}), 400
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        # Process data with R script (asynchronously)
        # Instead of writing JSON to file, pass the data directly
        task = process_with_r.delay(task_method_id, user_id, request_json)

        return jsonify(
            {"task_id": task.id, "message": "Preprocessing task submitted successfully"}
        )

    except Exception as e:
        print(traceback.format_exc())
        print(f"Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/task/<task_id>", methods=["GET"])
def task_status(task_id):
    """
    Get the status and result of a task by its ID.
    """
    task = AsyncResult(task_id)
    if task.state == "PENDING":
        response = {"state": task.state, "status": "Task is pending..."}
    elif task.state == "FAILURE":
        response = {
            "state": task.state,
            "status": "Task failed.",
            "error": str(task.info),
        }
    elif task.state == "SUCCESS":
        response = {
            "state": task.state,
            "status": "Task completed successfully!",
            "result": task.result,
        }
    else:
        response = {"state": task.state, "status": "Task is in progress..."}
    return jsonify(response)


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)
