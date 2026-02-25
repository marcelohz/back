from flask import Blueprint, send_from_directory

front_bp = Blueprint('front', __name__, template_folder="../out", static_folder="../out")

@front_bp.route("/")
def index():
    return send_from_directory(front_bp.static_folder, "index.html")

@front_bp.route("/<page>")
def serve_page(page):
    filename = f"{page}.html"
    try:
        return send_from_directory(front_bp.static_folder, filename)
    except FileNotFoundError:
        return "Página não encontrada", 404
    
@front_bp.route("/_next/<path:filename>")
def next_static(filename):
    return send_from_directory(f"{front_bp.static_folder}/_next", filename)