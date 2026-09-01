FROM python:3.13.15-slim-bookworm
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY agent.py .
CMD ["uvicorn", "agent:app", "--host", "0.0.0.0", "--port", "8000"]
