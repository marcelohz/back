def test_empresa_crud(client, create_empresa):
    # --- CREATE ---
    data = {
        "cnpj": "12345678000100",
        "nome": "Acme Ltda",
        "nome_fantasia": "Acme",
        "bairro": "Centro",
        "cidade": "Porto Alegre",
        "estado": "RS",
        "celular": "51999999999"
    }
    resp = client.post("/api/empresa", json=data)
    assert resp.status_code == 201
    result = resp.get_json()
    assert result["cnpj"] == data["cnpj"]
    assert result["message"] == "Empresa created"

    # --- CREATE DUPLICATE ---
    resp = client.post("/api/empresa", json=data)
    assert resp.status_code == 409
    assert resp.get_json()["error"] == "CNPJ already exists"

    # --- LIST ---
    resp = client.get("/api/empresa")
    assert resp.status_code == 200
    empresas = resp.get_json()
    assert any(e["cnpj"] == data["cnpj"] for e in empresas)

    # --- GET SINGLE ---
    resp = client.get(f"/api/empresa/{data['cnpj']}")
    assert resp.status_code == 200
    empresa = resp.get_json()
    assert empresa["cnpj"] == data["cnpj"]
    assert empresa["nome_fantasia"] == data["nome_fantasia"]
    assert "data_inclusao_eventual" in empresa

    # --- GET NON-EXISTENT ---
    resp = client.get("/api/empresa/00000000000000")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "Empresa not found"

    # --- UPDATE ---
    update_data = {"bairro": "Novo Bairro", "celular": "51988888888"}
    resp = client.put(f"/api/empresa/{data['cnpj']}", json=update_data)
    assert resp.status_code == 200
    assert "updated successfully" in resp.get_json()["message"]

    resp = client.get(f"/api/empresa/{data['cnpj']}")
    empresa = resp.get_json()
    assert empresa["bairro"] == "Novo Bairro"
    assert empresa["celular"] == "51988888888"

    # --- UPDATE NON-EXISTENT ---
    resp = client.put("/api/empresa/00000000000000", json=update_data)
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "Empresa not found"

    # --- DELETE ---
    resp = client.delete(f"/api/empresa/{data['cnpj']}")
    assert resp.status_code == 200
    assert "deleted successfully" in resp.get_json()["message"]

    resp = client.get(f"/api/empresa/{data['cnpj']}")
    assert resp.status_code == 404

    # --- DELETE NON-EXISTENT ---
    resp = client.delete("/api/empresa/00000000000000")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "Empresa not found"


def test_list_usuarios_of_empresa(client, create_empresa, create_usuario, login_empresa):
    empresa = login_empresa

    # Create a few users for this empresa
    u1 = create_usuario(email="user1@example.com", empresa=empresa)
    u2 = create_usuario(email="user2@example.com", empresa=empresa)
    u3 = create_usuario(email="user3@example.com")  # different empresa (None)

    # --- SUCCESS CASE: list users of logged-in empresa ---
    resp = client.get(f"/api/empresa/{empresa.cnpj}/usuarios")
    assert resp.status_code == 200
    data = resp.get_json()
    emails = [u["email"] for u in data]
    assert "user1@example.com" in emails
    assert "user2@example.com" in emails
    # Should NOT include user from another empresa
    assert "user3@example.com" not in emails

def test_list_usuarios_of_nonexistent_empresa(client, login_empresa):
    resp = client.get("/api/empresa/00000000000000/usuarios")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "Empresa not found"

def test_list_usuarios_unauthenticated(client, create_empresa):
    empresa = create_empresa()
    resp = client.get(f"/api/empresa/{empresa.cnpj}/usuarios")
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "Authentication required"

def test_list_usuarios_as_non_empresa_user(client, create_usuario, login_usuario):
    usuario = login_usuario
    resp = client.get(f"/api/empresa/{usuario.empresa_cnpj}/usuarios")
    assert resp.status_code == 403
    assert resp.get_json()["error"] == "Access restricted to empresa users"

def test_list_usuarios_of_other_empresa(client, create_empresa, create_usuario, login_empresa):
    empresa1 = login_empresa
    empresa2 = create_empresa(cnpj="22222222000100", nome="Other Ltda")
    u = create_usuario(email="user_other@example.com", empresa=empresa2)

    # Logged-in empresa tries to access another empresa's users
    resp = client.get(f"/api/empresa/{empresa2.cnpj}/usuarios")
    assert resp.status_code == 403
    assert resp.get_json()["error"] == "Access restricted to your own empresa"


def test_list_veiculos_of_empresa(client, create_empresa, create_veiculo, login_empresa):
    empresa = login_empresa

    # Create vehicles for this empresa
    v1 = create_veiculo(placa="VEIC001", empresa_cnpj=empresa.cnpj)
    v2 = create_veiculo(placa="VEIC002", empresa_cnpj=empresa.cnpj)
    v3 = create_veiculo(placa="VEIC003")  # Different empresa (None)

    # --- SUCCESS CASE: list vehicles of logged-in empresa ---
    resp = client.get(f"/api/empresa/{empresa.cnpj}/veiculos")
    assert resp.status_code == 200
    data = resp.get_json()
    placas = [v["placa"] for v in data]
    assert "VEIC001" in placas
    assert "VEIC002" in placas
    # Should NOT include vehicle from another empresa
    assert "VEIC003" not in placas

def test_list_veiculos_of_nonexistent_empresa(client, login_empresa):
    resp = client.get("/api/empresa/00000000000000/veiculos")
    assert resp.status_code == 404
    assert resp.get_json()["error"] == "Empresa not found"

def test_list_veiculos_unauthenticated(client, create_empresa):
    empresa = create_empresa()
    resp = client.get(f"/api/empresa/{empresa.cnpj}/veiculos")
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "Authentication required"

def test_list_veiculos_as_non_empresa_user(client, create_usuario, login_usuario):
    usuario = login_usuario
    # Use a dummy empresa CNPJ for testing
    resp = client.get(f"/api/empresa/11111111000100/veiculos")
    assert resp.status_code == 403
    assert resp.get_json()["error"] == "Access restricted to empresa users"

def test_list_veiculos_of_other_empresa(client, create_empresa, create_veiculo, login_empresa):
    empresa1 = login_empresa
    empresa2 = create_empresa(cnpj="22222222000100", nome="Other Ltda")
    v = create_veiculo(placa="VEIC_OTHER", empresa_cnpj=empresa2.cnpj)

    # Logged-in empresa tries to access another empresa's vehicles
    resp = client.get(f"/api/empresa/{empresa2.cnpj}/veiculos")
    assert resp.status_code == 403
    assert resp.get_json()["error"] == "Access restricted to your own empresa"