# Analysis Service

A microservice for handling asynchronous data analysis tasks using R scripts. This service offloads analytical workloads from your main platform, managing the queue processing and execution of data processing jobs.

## Features

- REST API for submitting data analysis tasks
- Asynchronous processing with Celery task queue
- R script execution for statistical analysis and data transformation
- Task status monitoring via API endpoints
- Scalable worker architecture for handling concurrent analysis requests

## Architecture

- **Flask API**: Provides HTTP endpoints for task submission and status checks
- **Celery Workers**: Handle asynchronous processing of analysis tasks
- **R Integration**: Executes R scripts for statistical analysis and data processing
- **Redis**: Acts as message broker for the task queue
- **Flower**: Web dashboard for monitoring task execution (optional)

## API Endpoints

- `POST /preprocess`: Submit data for analysis
  - Accepts JSON with a `data` field containing values to analyze
  - Returns a task ID for tracking the job

- `GET /task/<task_id>`: Check task status
  - Returns the current state and results (if complete)

## Local Development

### Prerequisites

- Python 3.7 or higher
- Redis (for local development)
- R with required packages

### Setup

1. Clone this repository
2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

3. Start Redis (if not already running):
   ```
   # For macOS with Homebrew
   brew services start redis
   
   # For Ubuntu/Debian
   sudo service redis-server start
   ```

4. Run the Flask application:
   ```
   python app.py
   ```

5. In a separate terminal, start the Celery worker:
   ```
   celery --app tasks worker --loglevel info
   ```

6. In another terminal, start Flower (optional):
   ```
   celery flower --app tasks --loglevel info
   ```

7. Access the application at http://localhost:8080

## Docker Development

### Prerequisites

- Docker
- Docker Compose

### Setup with Docker

1. Build and start all services:
   ```
   docker-compose up -d
   ```

2. Access the application:
   - Flask web app: http://localhost:8080
   - Flower dashboard: http://localhost:5555

3. View logs:
   ```
   docker-compose logs -f
   ```

### Using the Makefile

The project includes a Makefile for simpler commands:

```
make build      # Build Docker images
make up         # Start all services
make down       # Stop all services
make logs       # View logs from all services
make shell-web  # Open shell in web container
```

Run `make help` to see all available commands.

## Deploying to Render

### Using the Blueprint (render.yaml)

1. Fork this repository
2. Create a new Blueprint instance in your Render dashboard
3. Connect to your forked repository
4. Deploy the Blueprint

Render will automatically create all the required services:
- Flask web service
- Celery worker
- Flower dashboard
- Redis instance for message broker

## Security Note

The Flower dashboard provides unrestricted access to your Celery tasks and worker information. In a production environment, you should secure it with authentication as described in the [Flower documentation](https://flower.readthedocs.io/en/latest/auth.html).