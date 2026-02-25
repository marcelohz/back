import pytest
from werkzeug.security import check_password_hash
from models.usuario import Usuario

# --------------------------
# TEST LOGIN
# --------------------------
def test_login_success(client, create_usuario):
    # Arrange
    usuario = create_usuario(email="login@example.com", senha="mypassword")

    # Act
    resp = client.post("/api/autenticacao/login", json={"email": "login@example.com", "senha": "mypassword"})

    # Assert
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["message"] == "Logged in successfully"

def test_login_invalid_email(client, create_usuario):
    resp = client.post("/api/autenticacao/login", json={"email": "wrong@example.com", "senha": "mypassword"})
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "Invalid credentials"

def test_login_invalid_password(client, create_usuario):
    usuario = create_usuario(email="login2@example.com", senha="correctpassword")
    resp = client.post("/api/autenticacao/login", json={"email": "login2@example.com", "senha": "wrongpassword"})
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "Invalid credentials"

def test_login_missing_fields(client):
    resp = client.post("/api/autenticacao/login", json={"email": "email@example.com"})
    assert resp.status_code == 400
    assert resp.get_json()["error"] == "Email and password required"


# --------------------------
# TEST LOGOUT
# --------------------------
def test_logout(client, login_usuario):
    resp = client.post("/api/autenticacao/logout")
    assert resp.status_code == 200
    assert resp.get_json()["message"] == "Logged out successfully"


# --------------------------
# TEST PASSWORD CHANGE
# --------------------------
def test_change_password_success(client, login_usuario, db_session):
    usuario = login_usuario
    old_hash = usuario.senha

    resp = client.post("/api/autenticacao/change-password", json={
        "senha_atual": "secret",
        "nova_senha": "supersecret"
    })
    assert resp.status_code == 200
    assert resp.get_json()["message"] == "Password changed successfully"

    # Reload from DB
    updated_user = db_session.query(Usuario).get(usuario.id)
    db_session.refresh(usuario)
    assert updated_user.senha != old_hash
    assert check_password_hash(updated_user.senha, "supersecret")

def test_change_password_wrong_current(client, login_usuario):
    resp = client.post("/api/autenticacao/change-password", json={
        "senha_atual": "wrongpassword",
        "nova_senha": "newpass"
    })
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "Current password is incorrect"

def test_change_password_missing_fields(client, login_usuario):
    resp = client.post("/api/autenticacao/change-password", json={"senha_atual": "secret"})
    assert resp.status_code == 400
    assert resp.get_json()["error"] == "Both current and new passwords are required"

def test_change_password_unauthenticated(client):
    resp = client.post("/api/autenticacao/change-password", json={
        "senha_atual": "secret",
        "nova_senha": "newpass"
    })
