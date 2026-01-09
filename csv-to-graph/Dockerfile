FROM python:3.11-slim

LABEL maintainer="Android Memory Leak Analysis Tool"
LABEL description="CSV to Graph CLI for Android memory metrics visualization"

# Set working directory
WORKDIR /app

# Install system dependencies for matplotlib
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6 \
    libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY cli.py .

# Set entrypoint
ENTRYPOINT ["python", "cli.py"]

# Default help message
CMD ["--help"]
