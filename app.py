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

        directory_path = (
            f"./json/{task_method_id}_{method}_{timestamp}"
        )
        os.makedirs(directory_path, exist_ok=True)
        json_file_path = os.path.join(directory_path, "request_data.json")
        
        # === JSON CREATION DEBUGGING ===
        print("=== JSON CREATION DEBUG INFO ===")
        print(f"Creating JSON directory: {directory_path}")
        print(f"Directory absolute path: {os.path.abspath(directory_path)}")
        print(f"Current working directory: {os.getcwd()}")
        print(f"Directory exists after creation: {os.path.exists(directory_path)}")
        
        with open(json_file_path, "w") as f:
            json.dump(request_json, f, indent=2)

        # Verify JSON file creation
        print(f"JSON file path: {json_file_path}")
        print(f"JSON file absolute path: {os.path.abspath(json_file_path)}")
        print(f"JSON file exists: {os.path.exists(json_file_path)}")
        
        if os.path.exists(json_file_path):
            file_stats = os.stat(json_file_path)
            print(f"JSON file size: {file_stats.st_size} bytes")
            print(f"JSON file permissions: {oct(file_stats.st_mode)[-3:]}")
            
            # Read back and verify content
            try:
                with open(json_file_path, 'r') as f:
                    content = f.read()
                    print(f"JSON file content length: {len(content)} characters")
                    print(f"JSON file content (first 200 chars): {content[:200]}")
                    
                # Verify JSON is valid
                try:
                    parsed = json.loads(content)
                    print(f"JSON validation successful. Keys: {list(parsed.keys()) if isinstance(parsed, dict) else 'Not a dict'}")
                except json.JSONDecodeError as je:
                    print(f"JSON validation failed: {je}")
                    
            except Exception as e:
                print(f"Error reading back JSON file: {e}")
        else:
            print("ERROR: JSON file was not created!")
            
        # List directory contents
        if os.path.exists(directory_path):
            print(f"Contents of directory {directory_path}:")
            for item in os.listdir(directory_path):
                item_path = os.path.join(directory_path, item)
                print(f"  - {item} (size: {os.path.getsize(item_path)} bytes)")
        
        print("=== END JSON CREATION DEBUG INFO ===")

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
