from flask import Flask, jsonify, request, render_template
from tasks import process_with_r, pre_analysis_with_r
from celery.result import AsyncResult

app = Flask(__name__)


@app.route("/", methods=["GET", "POST"])
def index():
    return render_template("index.html")


@app.route("/pre-analysis", methods=["POST"])
def pre_analysis():
    """
    Purpose: Endpoint to generate preprocessing recommendations using R script.

    Expected JSON input format:
    {
        "task_id": "12345", 
        "columns": {            
            "age": [25, 30, 45],
            "income": [50000, 60000, 75000]
        },
        "target": "income",
        "model": "linear_regression"
    }
    """
    try:
        request_json = request.get_json()
 
        task_id = request_json.get("task_id")
        columns = request_json.get("columns")
        target = request_json.get("target")
        model = request_json.get("model")
        
        if not task_id or not columns or not target or not model:
            missing_fields = [field for field in ["task_id", "columns", "target", "model"] if not request_json.get(field)]
            return jsonify({"error": f"Missing required data: {', '.join(missing_fields)}"}), 400

        task = pre_analysis_with_r.delay(task_id, columns, target, model)

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
        "data": [value1, value2, ...] or {
            "column1": [value1, value2, ...],
            "column2": [value1, value2, ...],
            ...
        }
        ---------------------
        file_id in supabase
    }
    """
    try:
        # Get data from request
        request_json = request.get_json()
        if not request_json or 'file_id' not in request_json:
            return jsonify({"error": "No data or file_id provided"}), 400

        file_id = request_json.get('file_id')

        # # Handle array input by converting to dictionary with 'value' column
        # if isinstance(data, list):
        #     data_dict = {"value": data}
        # else:
        #     data_dict = data
        
        # Process data with R script (asynchronously)
        task = process_with_r.delay(file_id)

        return jsonify({
            "task_id": task.id,
            "message": "Preprocessing task submitted successfully"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/task/<task_id>", methods=["GET"])
def task_status(task_id):
    """
    Get the status and result of a task by its ID.
    """
    task = AsyncResult(task_id)
    if task.state == 'PENDING':
        response = {
            'state': task.state,
            'status': 'Task is pending...'
        }
    elif task.state == 'FAILURE':
        response = {
            'state': task.state,
            'status': 'Task failed.',
            'error': str(task.info)
        }
    elif task.state == 'SUCCESS':
        response = {
            'state': task.state,
            'status': 'Task completed successfully!',
            'result': task.result
        }
    else:
        response = {
            'state': task.state,
            'status': 'Task is in progress...'
        }
    return jsonify(response)


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=8080)
