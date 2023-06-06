# Use an official Python runtime as the base image
FROM python:3.10

# Set the working directory in the container
WORKDIR /python3

# Copy the requirements.txt file and install the dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container
COPY . .

# Set the command to run the Flask app
CMD [ "python", "app.py" ]