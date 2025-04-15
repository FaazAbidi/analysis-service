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

## API Endpoints

- `POST /preprocess`: Submit data for analysis
  - Accepts JSON with a `data` field containing values to analyze
  - Returns a task ID for tracking the job

- `GET /task/<task_id>`: Check task status
  - Returns the current state and results (if complete)

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

## Deployment to Production

Push the latest changes to the `main` branch, and Railway will automatically deploy the updated service.