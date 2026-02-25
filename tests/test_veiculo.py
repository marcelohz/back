def test_veiculo_crud(client, create_empresa, create_veiculo):
    empresa = create_empresa()
    v = create_veiculo(placa="AAA1111", empresa_cnpj=empresa.cnpj)

    # GET veiculo
    resp = client.get(f"/veiculo/{v.placa}")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["placa"] == "AAA1111"

    # LIST veiculos
    resp = client.get("/veiculo")
    veiculos = resp.get_json()
    assert any(v["placa"] == "AAA1111" for v in veiculos)

    # UPDATE veiculo
    resp = client.put(f"/veiculo/{v.placa}", json={"modelo": "Modelo Y"})
    assert resp.status_code == 200
    resp_get = client.get(f"/veiculo/{v.placa}")
    assert resp_get.get_json()["modelo"] == "Modelo Y"

    # DELETE veiculo
    resp = client.delete(f"/veiculo/{v.placa}")
    assert resp.status_code == 200


def test_veiculo_edge_cases(client, create_veiculo):
    # Missing required fields
    resp = client.post("/veiculo", json={"placa": "BBB1234"})
    assert resp.status_code == 400

    # Non-existing empresa
    resp = client.post("/veiculo", json={"placa": "CCC1234", "empresa_cnpj": "00000000000100"})
    assert resp.status_code == 400

    # Duplicate placa
    v = create_veiculo(placa="DDD1234")
    resp = client.post("/veiculo", json={"placa": "DDD1234"})
    assert resp.status_code in (400, 409)

    # Update non-existing vehicle
    resp = client.put("/veiculo/ZZZ9999", json={"modelo": "Modelo Y"})
    assert resp.status_code == 404

    # Delete non-existing vehicle
    resp = client.delete("/veiculo/ZZZ9999")
    assert resp.status_code == 404
