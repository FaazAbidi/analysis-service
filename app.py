import json
from flask import Flask, jsonify, request, render_template
from tasks import process_with_r
from celery.result import AsyncResult
import os

app = Flask(__name__)


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
        # Get data from request
        request_json = request.get_json()
        if not request_json or "taskMethodId" not in request_json:
            return jsonify({"error": "No data or file_id provided"}), 400

        json_file_path = (
            f"./json/{request_json.get('taskMethodId')}_{request_json.get('method')}"
        )
        with open(json_file_path, "w") as f:
            json.dump(request_json, f, indent=2)

        task_method_id: int = request_json.get("taskMethodId")

        # # Handle array input by converting to dictionary with 'value' column
        # if isinstance(data, list):
        #     data_dict = {"value": data}
        # else:
        #     data_dict = data

        # Process data with R script (asynchronously)
        task = process_with_r.delay(task_method_id, json_file_path)

        return jsonify(
            {"task_id": task.id, "message": "Preprocessing task submitted successfully"}
        )

    except Exception as e:
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
