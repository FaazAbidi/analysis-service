import os
import time
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

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@app.task
def pre_analysis_with_r(task_id, columns, target, model):
    """
    Process data and run R script in the background.

    Args:
        task_id (str): The unique task identifier.
        columns (list): Columns to be used for analysis.
        target (str): Target column for prediction.
        model (str): Model type for analysis.

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
        }
        with open(params_file, "w") as f:
            json.dump(params_data, f, indent=4)

        logger.info(f"Analysis parameters saved at: {params_file}")

        # Step 7: Execute R script
        r_script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "analysis", "preanalysis.R")
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
            "config": recommendations_data,
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
            "result": recommendations_data,
            "state": "SUCCESS",
            "status": "Task completed successfully!",
            "success": True
        }

    except Exception as e:
        logger.exception(f"Unhandled exception in pre_analysis_with_r for task ID {task_id}: {str(e)}")
        return {"error": str(e), "success": False}
  
@app.task
def process_with_r(file_id, output_filename=None):
    """
    Process data with R script in the background.
    
    Args:
        data_dict (dict): Dictionary containing data to process
        output_filename (str, optional): Name for the output file. If None, a timestamp-based name is used.

    Returns:
        dict: The processed data from R
    """
    # Create a timestamp for unique filenames if none provided
    timestamp = int(time.time())

    # Set filenames
    input_file = f"analysis/temp_input_{timestamp}.csv"
    if output_filename is None:
        output_file = f"analysis/temp_output_{timestamp}.csv"
    else:
        output_file = f"analysis/{output_filename}"

    # TODO: Dump the file in local computer before running the R Script
    # download file from supabase
    with open(f"./unprocessed_files/{file_id}.csv", "wb+") as f:
        response = (
            get_supabase_client().storage
                .from_('raw-data')
                .download('c4b6ca42-b2f9-40ef-8187-221a2abc09b0/temp/1745683584448_sample.csv')
        )
        f.write(response)

    try:
        # Convert dict to DataFrame if it's not already
        # TODO
        # if isinstance(data_dict, dict):
        #     df = pd.DataFrame(data_dict)
        # elif isinstance(data_dict, pd.DataFrame):
        #     df = data_dict
        # else:
        #     logger.error(f"Unsupported data type: {type(data_dict)}")
        #     return {"error": f"Unsupported data type: {type(data_dict)}", "success": False}
            
        # # Save input data to CSV
        # logger.info(f"Saving input data to {input_file}")
        # df.to_csv(input_file, index=False)
        
        # Get the directory of the current script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        r_script_path = os.path.join(script_dir, "analysis", "preprocess.R")

        logger.info(f"script_dir: {script_dir}")
        logger.info(f"r_script_path: {r_script_path}")
        
        # Make sure the R script is executable
        os.chmod(r_script_path, 0o755)
        
        # Run the R script as a subprocess
        logger.info(f"Running R script: {r_script_path}")
        process = subprocess.Popen(
            ["Rscript", r_script_path, input_file, output_file],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        
        # Get output and error
        stdout, stderr = process.communicate()
        
        # Log the R script output
        if stdout:
            logger.info(f"R script output:\n{stdout}")
        if stderr:
            logger.error(f"R script error:\n{stderr}")
            
        # Check if the process was successful
        if process.returncode != 0:
            logger.error(f"R script failed with return code {process.returncode}")
            return {"error": stderr, "success": False}
        
        # Read the processed data
        logger.info(f"Reading processed data from {output_file}")
        processed_data = pd.read_csv(output_file)
        
        # Clean up temporary files
        if "temp_input" in input_file:
            logger.info(f"Removing temporary input file {input_file}")
            os.remove(input_file)
        
        if "temp_output" in output_file:
            logger.info(f"Removing temporary output file {output_file}")
            os.remove(output_file)
            
        # Return the processed data as a dictionary
        # Convert to serializable format
        result_dict = {}
        for column in processed_data.columns:
            result_dict[column] = processed_data[column].tolist()
            
        return {"data": result_dict, "success": True}
    
    except Exception as e:
        logger.error(f"Error in process_with_r: {str(e)}")
        return {"error": str(e), "success": False}
