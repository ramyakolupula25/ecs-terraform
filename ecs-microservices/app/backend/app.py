from flask import Flask, jsonify, request
import os

app = Flask(__name__)

# In-memory data store
items = [
    {"id": 1, "name": "DevOps Project on ECS"},
    {"id": 2, "name": "Terraform Infrastructure"},
    {"id": 3, "name": "CI/CD with GitHub Actions"},
]

@app.route("/")
def home():
    return jsonify({
        "service": "backend",
        "status": "running",
        "version": "1.0",
        "environment": os.environ.get("ENV", "dev")
    })

@app.route("/health")
def health():
    return jsonify({"service": "backend", "status": "healthy"})

@app.route("/api/items", methods=["GET"])
def get_items():
    return jsonify({"items": items, "count": len(items)})

@app.route("/api/items", methods=["POST"])
def add_item():
    data = request.get_json()
    if not data or "name" not in data:
        return jsonify({"error": "name is required"}), 400
    new_item = {"id": len(items) + 1, "name": data["name"]}
    items.append(new_item)
    return jsonify(new_item), 201

@app.route("/api/items/<int:item_id>", methods=["DELETE"])
def delete_item(item_id):
    global items
    items = [i for i in items if i["id"] != item_id]
    return jsonify({"message": f"Item {item_id} deleted"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
