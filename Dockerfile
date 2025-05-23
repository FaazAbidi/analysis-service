FROM python:3.9-slim

WORKDIR /app

# Install R and required packages
RUN apt-get update && apt-get install -y \
    r-base \
    r-base-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install required R packages
RUN R -e "install.packages(c('readr', 'dplyr'), repos='https://cloud.r-project.org/')"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Command will be overridden in docker-compose.yml
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8080"]