from flask import Flask, request, jsonify
from flask_cors import CORS
from routes.auth import auth_bp
from routes.maternal import maternal_bp
from routes.tb import tb_bp
from routes.pesticide import pesticide_bp
from routes.dfu import dfu_bp
from routes.chw import chw_bp
from routes.whatsapp_setup import whatsapp_bp_new

app = Flask(__name__)
CORS(app)


app.register_blueprint(auth_bp)
app.register_blueprint(maternal_bp)
app.register_blueprint(tb_bp)
app.register_blueprint(pesticide_bp)
app.register_blueprint(dfu_bp)
app.register_blueprint(chw_bp)
app.register_blueprint(whatsapp_bp_new)

@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "message": "Flask API is running"
    })
@app.route('/favicon.ico')
def favicon():
    return '', 204

# Health Check Route
@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "success",
        "message": "API working properly"
    })


# Example POST API
@app.route("/predict", methods=["POST"])
def predict():
    try:
        data = request.get_json()

        # Example processing
        response = {
            "received_data": data,
            "result": "Processing successful"
        }

        return jsonify(response), 200

    except Exception as e:
        return jsonify({
            "error": str(e)
        }), 500


# Run Server
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
    