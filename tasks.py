import os
import time
import json
from celery import Celery
import logging
import subprocess
import json
import pandas as pd
from client.supabase import get_supabase_client

# Configure Celery
broker_url = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379")
result_backend = os.environ.get("CELERY_RESULT_BACKEND", "redis://localhost:6379")
app = Celery("tasks", broker=broker_url, backend=result_backend)

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

@app.task
def pre_analysis_with_r(task_id, columns, target, model, threshold_check_categorical, threshold_check_skewness, threshold_sampling, threshold_check_dimensionality, threshold_check_multicollinearity):
    """
    Process data and run R script in the background.

    Args:
        task_id (str): The unique task identifier.
        columns (list): List of columns to be used for analysis.
        target (str): The target column for prediction.
        model (str): The model type for analysis, e.g., 'linear_regression', 'decision_tree', etc.
        threshold_check_categorical (float): The threshold for checking categorical data.
        threshold_check_skewness (float): The threshold for checking skewness in data.
        threshold_sampling (int): The threshold for the number of samples.
        threshold_check_dimensionality (float): The threshold for checking data dimensionality.
        threshold_check_multicollinearity (float): The threshold for checking multicollinearity.
        
    Returns:
        dict: Processed recommendations or error message.
    """
    output_dir = "./files"
    os.makedirs(output_dir, exist_ok=True)

    try:
        # Initialize supabase client
        supabase = get_supabase_client()
        logger.info(f"Starting pre-analysis for task ID: {task_id}")

        # Step 1: Fetch task details
        task_response = supabase.table('TaskMethods') \
            .select('name', 'processed_file') \
            .eq('id', task_id) \
            .limit(1).execute()
        task_data = task_response.data

        # Handle missing task data
        if not task_data:
            logger.error(f"No matching task found with ID: {task_id}")
            return {"error": "No matching task found", "success": False}

        # Check if 'name' matches 'Original data'
        if task_data[0]['name'] != 'Original data':
            logger.warning(f"Invalid task type for ID {task_id}: Expected 'Original data', got '{task_data[0]['name']}'")
            return {"error": "This is not the original data file. Please verify the task details.", "success": False}

        # Step 2: Fetch processed file
        processed_file = task_data[0].get('processed_file')
        if not processed_file:
            logger.error(f"No processed file linked to task ID {task_id}")
            return {"error": "File not found", "success": False}

        # Step 3: Retrieve file path
        file_response = supabase.table('Files') \
            .select('path') \
            .eq('id', processed_file) \
            .limit(1).execute()
        file_data = file_response.data

        # Handle missing file path
        if not file_data:
            logger.error(f"File ID {processed_file} not found in Files table")
            return {"error": "File not found for file", "success": False}

        file_path = file_data[0]['path']
        safe_file_id = file_path.replace("/", "_")
        local_file_path = os.path.join(output_dir, os.path.basename(file_path))

        # Step 4: Define local paths for intermediate and output files
        params_file = os.path.join(output_dir, f"temp_params_{safe_file_id}.json")
        recommendations_file = os.path.join(output_dir, f"recommendations_{safe_file_id}.json")

        # Step 5: Download file from Supabase storage
        logger.info(f"Downloading file from Supabase storage: {file_path}")
        os.makedirs(os.path.dirname(local_file_path), exist_ok=True)
        file_content = supabase.storage.from_('raw-data').download(file_path)
        with open(local_file_path, "wb+") as f:
            f.write(file_content)

        # Handle file download failure
        if not os.path.exists(local_file_path):
            logger.error(f"Downloaded file missing: {local_file_path}")
            return {"error": "File download failed", "success": False}

        logger.info(f"File downloaded successfully at: {local_file_path}")

        # Step 6: Save parameters to JSON
        params_data = {
            "columns": columns,
            "target": target,
            "model": model,
            "task_id": task_id,
            "threshold_check_categorical": threshold_check_categorical,
            "threshold_check_skewness": threshold_check_skewness,
            "threshold_sampling": threshold_sampling,
            "threshold_check_dimensionality": threshold_check_dimensionality,
            "threshold_check_multicollinearity": threshold_check_multicollinearity
        }

        with open(params_file, "w") as f:
            json.dump(params_data, f, indent=4)

        logger.info(f"Analysis parameters saved at: {params_file}")

        # Step 7: Execute R script
        r_script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis", "pre_analysis_pipeline.R")
        os.chmod(r_script_path, 0o755)
        logger.info("Executing R script for analysis")

        process = subprocess.Popen(
            ["Rscript", r_script_path, os.path.abspath(params_file), os.path.abspath(local_file_path), os.path.abspath(recommendations_file)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        stdout, stderr = process.communicate()

        if stdout:
            logger.info(f"R script output:\n{stdout}")
        if stderr:
            logger.error(f"R script error output:\n{stderr}")
        if process.returncode != 0:
            logger.error(f"R script execution failed with code {process.returncode}")
            return {"error": stderr, "success": False}

        # Step 8: Load recommendations file
        if not os.path.exists(recommendations_file):
            logger.error(f"Expected output file not found: {recommendations_file}")
            return {"error": "Processed recommendations file missing", "success": False}

        with open(recommendations_file, "r") as f:
            recommendations_data = json.load(f)

        logger.info(f"Recommendations data loaded from: {recommendations_file}")

        # Step 9: Update recommendations in the database
        update_data = {
            "pre_analysis": recommendations_data,
        }
        update_response = supabase.table('TaskMethods') \
            .update(update_data) \
            .eq('id', task_id).execute()

        # Handle database update failure
        if not update_response.data:
            logger.error(f"Failed to update TaskMethods with ID {task_id}")
            return {"error": "Failed to update TaskMethods table", "success": False}

        logger.info(f"TaskMethods table successfully updated for task ID {task_id}")

        # Step 10: Return success response
        return {
            "success": True
        }

    except Exception as e:
        logger.exception(f"Unhandled exception in pre_analysis_with_r for task ID {task_id}: {str(e)}")
        return {"error": str(e), "success": False}
  
@app.task
def process_with_r(task_method_id: int, user_id: str, json_data: dict):
    """
    Process data with R script in the background.

    Args:
        task_method_id (int): ID of the task method
        user_id (str): User ID
        json_data (dict): JSON data directly instead of file path

    Returns:
        dict: The processed data from R
    """
    # Create a timestamp for unique filenames if none provided
    timestamp = int(time.time())
    is_original_data = False

    try:
        supabase_client = get_supabase_client()

        task_method = (
            supabase_client.table("TaskMethods")
            .select("*")
            .eq("id", task_method_id)
            .single()
            .execute()
            .data
        )
        if task_method is None:
            raise Exception("TaskMethod not found for id" + task_method_id)
        
        prev_version: int = task_method.get("prev_version")
        
        if task_method.get('name') == 'Original data':
            is_original_data = True
        
        file_id = None
        # get parent file id
        parent_file_id = (
            supabase_client.table("TaskMethods")
            .select("*")
            .eq("id", prev_version)
            .single()
            .execute()
            .data
        )
    
        if not parent_file_id:
            raise Exception(f"Parent file not found for id {prev_version}")
        
        parent_task_name = parent_file_id.get("name")
        parent_file_id = parent_file_id.get("processed_file")
        file_id = parent_file_id

        if parent_task_name == 'Original data':
            is_original_data = True

        if not file_id:
            raise Exception(f"Parent file not found for id {parent_file_id}")

        file_result = (
            supabase_client.table("Files")
            .select("id, path, file_name")
            .eq("id", file_id)
            .execute()
        )

        if not file_result.data:
            raise Exception(f"File not found for id {parent_file_id}")

        file = file_result.data[0]

        logger.info(f"TaskMethod: {json.dumps(file, indent=2)}")
        
        storage_file_path = file.get("path")
        file_name = file.get("file_name")
        # Create a directory for this specific task run using a timestamp
        task_directory = f"./unprocessed_files/{timestamp}"
        os.makedirs(task_directory, exist_ok=True)

        # Construct the full path to the input file within the task-specific directory
        input_file_path: str = os.path.join(task_directory, file_name)

        logger.info(f"File path: {input_file_path}")
        
        bucket_name = None
        if is_original_data:
            bucket_name = "raw-data"
        else:
            bucket_name = "processed-data"
            
        logger.info(f"is_original_data: {is_original_data}")
        logger.info(f"storage_file_path: {storage_file_path}")
        logger.info(f"bucket_name: {bucket_name}")

        file_content = supabase_client.storage.from_(bucket_name).download(storage_file_path)
        # download file from supabase
        with open(input_file_path, "wb+") as f:
            f.write(file_content)
            logger.info("File download from supabase complete!")

        # Get the directory of the current script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        r_script_path = os.path.join(script_dir, "analysis", "pre_processing_pipeline.R")

        logger.info(f"script_dir: {script_dir}")
        logger.info(f"r_script_path: {r_script_path}")

        # # Make sure the R script is executable
        os.chmod(r_script_path, 0o755)
        
        output_directory_path = (
            f"./processed_files/{task_method_id}"
        )
        os.makedirs(output_directory_path, exist_ok=True)
        output_file_path = os.path.join(output_directory_path, file_name)

        # === CREATE JSON FILE IN WORKER CONTAINER ===
        logger.info("=== JSON FILE CREATION IN WORKER ===")
        logger.info(f"Received JSON data: {json_data}")
        logger.info(f"JSON data type: {type(json_data)}")
        logger.info(f"Current working directory: {os.getcwd()}")
        
        # Create JSON file in worker container's temp directory
        import tempfile
        temp_json_dir = tempfile.mkdtemp(prefix="json_")
        json_file_path = os.path.join(temp_json_dir, "request_data.json")
        
        logger.info(f"Creating temporary JSON file at: {json_file_path}")
        
        try:
            with open(json_file_path, "w") as f:
                json.dump(json_data, f, indent=2)
            
            # Verify file creation
            if os.path.exists(json_file_path):
                file_stats = os.stat(json_file_path)
                logger.info(f"JSON file created successfully - size: {file_stats.st_size} bytes")
                
                # Read back to verify
                with open(json_file_path, 'r') as f:
                    content = f.read()
                    logger.info(f"JSON file content verified - length: {len(content)} characters")
            else:
                raise Exception("JSON file was not created")
                
        except Exception as e:
            logger.error(f"Error creating JSON file: {e}")
            raise
            
        logger.info("=== JSON FILE READY FOR R SCRIPT ===")

        # # Run the R script as a subprocess
        process = subprocess.Popen(
            ["Rscript", r_script_path, json_file_path, input_file_path, output_file_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )

        logger.info("RScript executed.")

        # # Get output and error
        stdout, stderr = process.communicate()

        # # Log the R script output
        if stdout:
            logger.info(f"R script output:\n{stdout}")
        if stderr:
            logger.error(f"R script error:\n{stderr}")

        # Clean up temporary JSON file
        try:
            os.remove(json_file_path)
            os.rmdir(temp_json_dir)
            logger.info("Temporary JSON file cleaned up")
        except Exception as e:
            logger.warning(f"Could not clean up temporary JSON file: {e}")

        # # Check if the process was successful
        if process.returncode != 0:
            logger.error(f"R script failed with return code {process.returncode}")
            return {"error": stderr, "success": False}

        # # Read the processed data
        logger.info(f"Reading processed data from {output_file_path}")
        processed_data = pd.read_csv(output_file_path)
        
        # calculate file size
        file_size = os.path.getsize(output_file_path)

        with open(output_file_path, "rb") as f:
            # TODO: get files from raw-data if the version is not original
            processed_file = supabase_client.storage.from_("processed-data").upload(
                file=f,
                path=f"{user_id}/{timestamp}/{file_name}",
                file_options={"cache-control": "3600", "upsert": "false"},
            )
        logger.info(f"processed file path: {processed_file.path}")
        new_file_id = (
            supabase_client.table("Files")
            .insert(
                {
                    "path": processed_file.path,
                    "file_name": f"{file_name}",
                    "file_size": file_size
                }
            ).execute().data[0].get("id")
        )
        logger.info(f"new_file_id: {new_file_id}")

        supabase_client.table("TaskMethods").update(
            {"processed_file": new_file_id, "status": "PROCESSED"}
        ).eq("id", task_method_id).execute()

        # Clean up temporary files
        logger.info(f"Removing temporary input file {input_file_path}")
        os.remove(input_file_path)

        logger.info(f"Removing temporary output file {output_file_path}")
        os.remove(output_file_path)

        # # Return the processed data as a dictionary
        # # Convert to serializable format
        result_dict = {}
        for column in processed_data.columns:
            result_dict[column] = processed_data[column].tolist()

        return {"success": True}

    except Exception as e:
        logger.error(f"Error in process_with_r: {str(e)}")
        return {"error": str(e), "success": False}
