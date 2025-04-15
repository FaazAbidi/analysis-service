# Celery on Render

This sample application demonstrates how to deploy the Celery distributed task queue on Render. It includes:

1. A Flask web application for creating tasks
2. A Celery worker for processing tasks
3. Flower, a web monitoring frontend for Celery
4. Redis as the message broker

## Local Development

### Prerequisites

- Python 3.7 or higher
- Redis (for local development)

### Setup

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/flask-celery-render.git
   cd flask-celery-render
   ```

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

4. Stop all services:
   ```
   docker-compose down
   ```

### Using the Makefile

The project includes a Makefile for simpler commands:

```
make build      # Build Docker images
make up         # Start all services
make down       # Stop all services
make logs       # View logs from all services
make ps         # List running containers
make shell-web  # Open shell in web container
make clean      # Remove containers
make clean-all  # Remove containers, volumes, and images
```

Run `make help` to see all available commands.

## Deploying to Render

### Option 1: Using the Blueprint (render.yaml)

1. Fork this repository
2. Create a new Blueprint instance in your Render dashboard
3. Connect to your forked repository
4. Deploy the Blueprint

Render will automatically create all the required services:
- Flask web service
- Celery worker
- Flower dashboard
- Redis instance for message broker

### Option 2: Manual Deployment

Follow the step-by-step guide at [Render's documentation](https://render.com/docs/deploy-celery) to manually set up the services.

## Architecture

- **app.py**: Flask web application that provides a UI for creating tasks
- **tasks.py**: Contains Celery task definitions
- **Dockerfile**: Defines the container image for all services
- **docker-compose.yml**: Orchestrates all containers
- **Makefile**: Simplifies common Docker operations
- **render.yaml**: Configuration for deploying to Render

## Security Note

The Flower dashboard provides unrestricted access to your Celery tasks and worker information. In a production environment, you should secure it with authentication as described in the [Flower documentation](https://flower.readthedocs.io/en/latest/auth.html). 