from flask import Flask, jsonify, render_template_string
import requests
import os

app = Flask(__name__)

BACKEND_URL = os.environ.get("BACKEND_URL", "http://localhost:5001")

HTML_PAGE = """
<!DOCTYPE html>
<html>
<head>
  <title>ECS Microservices App</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
    h1 { color: #232f3e; }
    .card { background: #f8f8f8; border-radius: 8px; padding: 20px; margin: 20px 0; }
    .status { color: green; font-weight: bold; }
  </style>
</head>
<body>
  <h1>🚀 ECS Microservices - Frontend</h1>
  <div class="card">
    <h2>Frontend Service</h2>
    <p class="status">✅ Running on ECS Fargate</p>
    <p>Backend URL: {{ backend_url }}</p>
  </div>
  <div class="card">
    <h2>Items from Backend API</h2>
    {% if items %}
      <ul>{% for item in items %}<li>{{ item.name }}</li>{% endfor %}</ul>
    {% else %}
      <p>Could not connect to backend.</p>
    {% endif %}
  </div>
</body>
</html>
"""

@app.route("/")
def home():
    items = []
    try:
        resp = requests.get(f"{BACKEND_URL}/api/items", timeout=3)
        items = resp.json().get("items", [])
    except Exception:
        pass
    return render_template_string(HTML_PAGE, items=items, backend_url=BACKEND_URL)

@app.route("/health")
def health():
    return jsonify({"service": "frontend", "status": "healthy"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
