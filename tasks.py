import os
import time
import json
from celery import Celery
import logging
import subprocess
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
def process_with_r(task_method_id: int, user_id: str, json_file_path: str):
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

        # === JSON FILE DEBUGGING ===
        logger.info("=== JSON FILE DEBUG INFO ===")
        logger.info(f"JSON file path received: {json_file_path}")
        logger.info(f"JSON file absolute path: {os.path.abspath(json_file_path) if json_file_path else 'None'}")
        logger.info(f"Current working directory: {os.getcwd()}")
        logger.info(f"JSON file exists: {os.path.exists(json_file_path) if json_file_path else 'False'}")
        
        if json_file_path and os.path.exists(json_file_path):
            try:
                file_stats = os.stat(json_file_path)
                logger.info(f"JSON file size: {file_stats.st_size} bytes")
                logger.info(f"JSON file permissions: {oct(file_stats.st_mode)[-3:]}")
                
                # Read and log file content
                with open(json_file_path, 'r') as f:
                    content = f.read()
                    logger.info(f"JSON file full content: {content}")
                    logger.info(f"JSON file content length: {len(content)} characters")
                    
                # Try to parse JSON to check validity
                try:
                    import json
                    parsed = json.loads(content)
                    logger.info(f"JSON parsing successful. Keys: {list(parsed.keys()) if isinstance(parsed, dict) else 'Not a dict'}")
                except json.JSONDecodeError as je:
                    logger.error(f"JSON parsing failed: {je}")
                    logger.error(f"JSON error at position: {je.pos if hasattr(je, 'pos') else 'unknown'}")
                    
            except Exception as e:
                logger.error(f"Error reading JSON file: {e}")
        else:
            logger.error("JSON file does not exist or path is None!")
            
        # List contents of json directory if it exists
        json_dir = os.path.dirname(json_file_path) if json_file_path else None
        if json_dir and os.path.exists(json_dir):
            logger.info(f"Contents of JSON directory {json_dir}:")
            try:
                for item in os.listdir(json_dir):
                    item_path = os.path.join(json_dir, item)
                    logger.info(f"  - {item} (size: {os.path.getsize(item_path)} bytes)")
            except Exception as e:
                logger.error(f"Error listing JSON directory: {e}")
        else:
            logger.error(f"JSON directory does not exist: {json_dir}")
            
        # List contents of current directory
        logger.info("Contents of current working directory:")
        try:
            for item in os.listdir('.'):
                if os.path.isdir(item):
                    logger.info(f"  [DIR] {item}")
                else:
                    logger.info(f"  [FILE] {item} (size: {os.path.getsize(item)} bytes)")
        except Exception as e:
            logger.error(f"Error listing current directory: {e}")
            
        logger.info("=== END JSON DEBUG INFO ===")

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
