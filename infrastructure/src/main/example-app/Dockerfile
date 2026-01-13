# Example Docker Image for Lambda Web App
# This creates a simple Python web application that runs on AWS Lambda

# Use AWS Lambda Python base image (supports ARM64)
FROM public.ecr.aws/lambda/python:3.12

# Install dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}/
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py ${LAMBDA_TASK_ROOT}/

# Set the CMD to your handler
CMD [ "app.handler" ]
