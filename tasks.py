import os
import time
from celery import Celery
import logging
import os
import subprocess
import pandas as pd
from client.supabase import get_supabase_client

# Configure Celery
broker_url = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379")
result_backend = os.environ.get("CELERY_RESULT_BACKEND", "redis://localhost:6379")
app = Celery("tasks", broker=broker_url, backend=result_backend)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


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
    input_file = f'{os.environ.get("BASE_RAW_DATA_FOLDER_PATH")}/{file_id}.csv'
    if output_filename is None:
        output_file = f"analysis/temp_output_{timestamp}.csv"
    else:
        output_file = f"analysis/{output_filename}"

    try:
        # TODO: Dump the file in local computer before running the R Script
        # download file from supabase
        with open(f"./unprocessed_files/{file_id}.csv", "wb+") as f:
            response = (
            get_supabase_client().storage
                .from_('raw-data')
                .download(
                    f'{os.environ.get("BASE_RAW_DATA_FOLDER_PATH")}/{file_id}.csv'
                )
            )
            f.write(response)
        logger.info('File download from supabase complete!')
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
