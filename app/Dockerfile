FROM python:3.9-slim

WORKDIR /app

COPY jpeg_to_grayscale.py .
COPY input.jpg .

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "jpeg_to_grayscale.py"]

