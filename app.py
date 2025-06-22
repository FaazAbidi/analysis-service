from datetime import datetime
import json
from flask import Flask, jsonify, request, render_template
from tasks import process_with_r, pre_analysis_with_r
from celery.result import AsyncResult
import os
import traceback
from flask_cors import CORS


app = Flask(__name__)
CORS(app)


@app.route("/", methods=["GET", "POST"])
def index():
    return render_template("index.html")


@app.route("/pre-analysis", methods=["POST"])
def pre_analysis():
    """
    Purpose: Endpoint to generate preprocessing recommendations using R script.

    Expected JSON input format:
    {
        "task_id": "1234",
        "method": "pre_analysis",
        "model": "Logistic Regression",
        "target": "num_feature_80",
        "threshold_check_categorical": 0.3,
        "threshold_check_skewness": 1,
        "threshold_sampling": 100,
        "threshold_check_dimensionality": 0.5,
        "threshold_check_multicollinearity": 0.8,
        "columns": {
            "num_feature_40": {
            "type": "QUANTITATIVE",
            "step": null,
            "value": null
            },
            "num_feature_41": {
            "type": "QUANTITATIVE",
            "step": null,
            "value": null
            },
            "num_feature_42": {
            "type": "QUANTITATIVE",
            "step": null,
            "value": null
            }
        }
    }
    """
    try:
        request_json = request.get_json()
 
        task_id = request_json.get("task_id")
        columns = request_json.get("columns")
        target = request_json.get("target")
        model = request_json.get("model")
        threshold_check_categorical = request_json.get("threshold_check_categorical")
        threshold_check_skewness = request_json.get("threshold_check_skewness")
        threshold_sampling = request_json.get("threshold_sampling")
        threshold_check_dimensionality = request_json.get("threshold_check_dimensionality")
        threshold_check_multicollinearity = request_json.get("threshold_check_multicollinearity")
        
        if not task_id or not columns or not model:
            missing_fields = [field for field in ["task_id", "columns", "model"] if not request_json.get(field)]
            return jsonify({"error": f"Missing required data: {', '.join(missing_fields)}"}), 400

        task = pre_analysis_with_r.delay(task_id, columns, target, model, threshold_check_categorical, threshold_check_skewness, threshold_sampling, threshold_check_dimensionality, threshold_check_multicollinearity)

        return jsonify({
            "task_id": task.id, 
            "message": "Pre analysis task submitted successfully"
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500


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

        directory_path = (
            f"./json/{task_method_id}_{method}_{timestamp}"
        )
        os.makedirs(directory_path, exist_ok=True)
        json_file_path = os.path.join(directory_path, "request_data.json")
        with open(json_file_path, "w") as f:
            json.dump(request_json, f, indent=2)

        # Process data with R script (asynchronously)
        task = process_with_r.delay(task_method_id, user_id, json_file_path)

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
