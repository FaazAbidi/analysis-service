# Use our custom R base image from Docker Hub
# Replace 'faazabidi' with your actual Docker Hub username
FROM faazabidi/analysis-service-r-base:latest

# Copy Python requirements and install them
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Command will be overridden in docker-compose.yml
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8080"]