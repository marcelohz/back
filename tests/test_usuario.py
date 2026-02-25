import pytest
from werkzeug.security import check_password_hash


# --------------------------
# TEST CRUD FOR USUARIO
# --------------------------
def test_usuario_crud(client, create_empresa, login_empresa):
    empresa = login_empresa

    # --- CREATE ---
    data = {
        "email": "newuser@example.com",
        "nome": "New User",
        "senha": "pass123",
        "cpf": "12345678901",
        "telefone": "12345678",
        "celular": "99999999",
        "papel_nome": "EMPRESA",
        "eh_empresa": False
    }
    resp = client.post("/api/usuario", json=data)
    assert resp.status_code == 201
    result = resp.get_json()
    user_id = result["id"]
    assert result["message"] == "Usuario created"

    # --- CREATE DUPLICATE EMAIL ---
    resp = client.post("/api/usuario", json=data)
    assert resp.status_code == 409
    assert resp.get_json()["error"] == "Email already exists"

    # --- LIST USERS ---
    resp = client.get("/api/usuario")
    assert resp.status_code == 200
    users = resp.get_json()
    assert any(u["email"] == "newuser@example.com" for u in users)

    # --- GET SINGLE ---
    resp = client.get(f"/api/usuario/{user_id}")
    assert resp.status_code == 200
    user = resp.get_json()
    assert user["email"] == "newuser@example.com"

    # --- UPDATE ---
    update_data = {"nome": "Updated Name", "senha": "newpass123"}
    resp = client.put(f"/api/usuario/{user_id}", json=update_data)
    assert resp.status_code == 200
    assert "updated successfully" in resp.get_json()["message"]

    # --- VERIFY UPDATE ---
    resp = client.get(f"/api/usuario/{user_id}")
    user = resp.get_json()
    assert user["nome"] == "Updated Name"

    # --- DELETE ---
    resp = client.delete(f"/api/usuario/{user_id}")
    assert resp.status_code == 200
    assert "deleted successfully" in resp.get_json()["message"]

    # --- VERIFY DELETE ---
    resp = client.get(f"/api/usuario/{user_id}")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "Usuario not found"


