--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18
-- Dumped by pg_dump version 14.18

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: admin; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA admin;


ALTER SCHEMA admin OWNER TO metroplan;

--
-- Name: app; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA app;


ALTER SCHEMA app OWNER TO metroplan;

--
-- Name: concessao; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA concessao;


ALTER SCHEMA concessao OWNER TO metroplan;

--
-- Name: eventual; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA eventual;


ALTER SCHEMA eventual OWNER TO postgres;

--
-- Name: fretamento; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA fretamento;


ALTER SCHEMA fretamento OWNER TO metroplan;

--
-- Name: geral; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA geral;


ALTER SCHEMA geral OWNER TO metroplan;

--
-- Name: gm; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA gm;


ALTER SCHEMA gm OWNER TO metroplan;

--
-- Name: motorista; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA motorista;


ALTER SCHEMA motorista OWNER TO metroplan;

--
-- Name: multas; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA multas;


ALTER SCHEMA multas OWNER TO metroplan;

--
-- Name: postgres; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA postgres;


ALTER SCHEMA postgres OWNER TO metroplan;

--
-- Name: saac; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA saac;


ALTER SCHEMA saac OWNER TO metroplan;

--
-- Name: temp; Type: SCHEMA; Schema: -; Owner: metroplan
--

CREATE SCHEMA temp;


ALTER SCHEMA temp OWNER TO metroplan;

--
-- Name: web; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA web;


ALTER SCHEMA web OWNER TO postgres;

--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: autentica(text, text); Type: FUNCTION; Schema: admin; Owner: metroplan
--

CREATE FUNCTION admin.autentica(u text, s text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  sucesso boolean;
  begin

    sucesso = exists (select usuario from admin.usuario where nome = lower(u) and (senha = s or senha = lower(md5(s))));
    INSERT INTO admin.log(data, usuario_nome, sucesso, ip_remoto) VALUES (now(), u, sucesso, inet_client_addr());
    return sucesso;

end;$$;


ALTER FUNCTION admin.autentica(u text, s text) OWNER TO metroplan;

--
-- Name: autentica2(text, text, inet, text, text); Type: FUNCTION; Schema: admin; Owner: metroplan
--

CREATE FUNCTION admin.autentica2(u text, s text, ip inet, u_os text, host text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
  sucesso boolean;
  begin

    sucesso = exists (select usuario from admin.usuario where nome = lower(u) and (senha = s or senha = lower(md5(s))));
    if sucesso then
	INSERT INTO admin.log(data, usuario_nome, sucesso, ip_remoto, ip_local, usuario_os, hostname) VALUES (now(), u, sucesso, inet_client_addr(), ip, u_os, host);
    end if;
    return sucesso;

end;$$;


ALTER FUNCTION admin.autentica2(u text, s text, ip inet, u_os text, host text) OWNER TO metroplan;

--
-- Name: bod_meses_pivot(integer, text, text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.bod_meses_pivot(p_ano integer, p_regiao_codigo text, coluna text) RETURNS TABLE(ano integer, regiao_codigo text, empresa_codigo text, empresa_nome text, empresa_nome_simplificado text, janeiro numeric, fevereiro numeric, marco numeric, abril numeric, maio numeric, junho numeric, julho numeric, agosto numeric, setembro numeric, outubro numeric, novembro numeric, dezembro numeric, total numeric)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    sql_query TEXT;
BEGIN
    -- Constructing the dynamic SQL query
    sql_query := format($f$
        WITH dados AS (
            SELECT 
                ano,
                empresa_codigo.regiao_codigo, 
                empresa_codigo,
                empresa.nome AS empresa_nome,
                empresa.nome_simplificado AS empresa_nome_simplificado,
                SUM(CASE WHEN mes = 1 THEN %I::numeric ELSE 0 END) AS janeiro,
                SUM(CASE WHEN mes = 2 THEN %I::numeric ELSE 0 END) AS fevereiro,
                SUM(CASE WHEN mes = 3 THEN %I::numeric ELSE 0 END) AS marco,
                SUM(CASE WHEN mes = 4 THEN %I::numeric ELSE 0 END) AS abril,
                SUM(CASE WHEN mes = 5 THEN %I::numeric ELSE 0 END) AS maio,
                SUM(CASE WHEN mes = 6 THEN %I::numeric ELSE 0 END) AS junho,
                SUM(CASE WHEN mes = 7 THEN %I::numeric ELSE 0 END) AS julho,
                SUM(CASE WHEN mes = 8 THEN %I::numeric ELSE 0 END) AS agosto,
                SUM(CASE WHEN mes = 9 THEN %I::numeric ELSE 0 END) AS setembro,
                SUM(CASE WHEN mes = 10 THEN %I::numeric ELSE 0 END) AS outubro,
                SUM(CASE WHEN mes = 11 THEN %I::numeric ELSE 0 END) AS novembro,
                SUM(CASE WHEN mes = 12 THEN %I::numeric ELSE 0 END) AS dezembro
            FROM 
                concessao.bod
                JOIN geral.empresa_codigo ON bod.empresa_codigo = empresa_codigo.codigo
                JOIN geral.empresa ON geral.empresa_codigo.empresa_cnpj = empresa.cnpj
            WHERE 
                ano = %L AND empresa_codigo.regiao_codigo = %L  -- Filters for year and region
            GROUP BY 
                ano, empresa_codigo.regiao_codigo, empresa_codigo, empresa.nome, empresa.nome_simplificado
        )
        SELECT 
            ano,
            regiao_codigo,
            empresa_codigo,
            empresa_nome,
            empresa_nome_simplificado,
            janeiro,
            fevereiro,
            marco,
            abril,
            maio,
            junho,
            julho,
            agosto,
            setembro,
            outubro,
            novembro,
            dezembro,
            (janeiro + fevereiro + marco + abril + maio + junho +
             julho + agosto + setembro + outubro + novembro + dezembro) AS total
        FROM 
            dados
        ORDER BY 
            ano, empresa_codigo;
    $f$, coluna, coluna, coluna, 
         coluna, coluna, coluna, 
         coluna, coluna, coluna, 
         coluna, coluna, coluna, 
         p_ano, p_regiao_codigo);

    -- Execute the dynamically generated SQL query
    RETURN QUERY EXECUTE sql_query;
END;
$_$;


ALTER FUNCTION concessao.bod_meses_pivot(p_ano integer, p_regiao_codigo text, coluna text) OWNER TO metroplan;

--
-- Name: bod_meses_pivot_array(integer, text, text[]); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.bod_meses_pivot_array(p_ano integer, p_regiao_codigo text, p_colunas text[]) RETURNS TABLE(ano integer, regiao_codigo text, empresa_codigo text, empresa_nome text, empresa_nome_simplificado text, janeiro numeric, fevereiro numeric, marco numeric, abril numeric, maio numeric, junho numeric, julho numeric, agosto numeric, setembro numeric, outubro numeric, novembro numeric, dezembro numeric, total numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    combined RECORD; -- Store each individual row from the pivot function
    col_name TEXT;
BEGIN
    -- Create a temporary table to store the combined rows
    CREATE TEMP TABLE temp_results (
        ano INTEGER,
        regiao_codigo TEXT,
        empresa_codigo TEXT,
        empresa_nome TEXT,
        empresa_nome_simplificado TEXT,
        janeiro NUMERIC(12,2),
        fevereiro NUMERIC(12,2),
        marco NUMERIC(12,2),
        abril NUMERIC(12,2),
        maio NUMERIC(12,2),
        junho NUMERIC(12,2),
        julho NUMERIC(12,2),
        agosto NUMERIC(12,2),
        setembro NUMERIC(12,2),
        outubro NUMERIC(12,2),
        novembro NUMERIC(12,2),
        dezembro NUMERIC(12,2),
        total NUMERIC(12,2)
    );

    -- Iterate over each passenger type in the provided array
    FOREACH col_name IN ARRAY p_colunas
    LOOP
        -- Call the pivot function for each passenger type and get the results
        FOR combined IN 
            SELECT
				fun.ano AS ano,
				fun.regiao_codigo as regiao_codigo,
                fun.empresa_codigo AS empresa_codigo,
                fun.empresa_nome AS empresa_nome,
                fun.empresa_nome_simplificado AS empresa_nome_simplificado,
                fun.janeiro AS janeiro,
                fun.fevereiro AS fevereiro,
                fun.marco AS marco,
                fun.abril AS abril,
                fun.maio AS maio,
                fun.junho AS junho,
                fun.julho AS julho,
                fun.agosto AS agosto,
                fun.setembro AS setembro,
                fun.outubro AS outubro,
                fun.novembro AS novembro,
                fun.dezembro AS dezembro,
                fun.total AS total
            FROM concessao.bod_meses_pivot(p_ano, p_regiao_codigo, col_name) AS fun
        LOOP
            -- Insert each combined row into the temporary table
            INSERT INTO temp_results (
                ano,
                regiao_codigo,
                empresa_codigo,
                empresa_nome,
                empresa_nome_simplificado,
                janeiro,
                fevereiro,
                marco,
                abril,
                maio,
                junho,
                julho,
                agosto,
                setembro,
                outubro,
                novembro,
                dezembro,
                total
            ) VALUES (
                combined.ano,
                combined.regiao_codigo,
                combined.empresa_codigo,
                combined.empresa_nome,
                combined.empresa_nome_simplificado,
                combined.janeiro,
                combined.fevereiro,
                combined.marco,
                combined.abril,
                combined.maio,
                combined.junho,
                combined.julho,
                combined.agosto,
                combined.setembro,
                combined.outubro,
                combined.novembro,
                combined.dezembro,
                combined.total
            );
        END LOOP;
    END LOOP;

RETURN QUERY 
    SELECT 
        temp_results.ano,
        temp_results.regiao_codigo,
        temp_results.empresa_codigo,
        temp_results.empresa_nome,
        temp_results.empresa_nome_simplificado,
        SUM(temp_results.janeiro) AS janeiro,
        SUM(temp_results.fevereiro) AS fevereiro,
        SUM(temp_results.marco) AS marco,
        SUM(temp_results.abril) AS abril,
        SUM(temp_results.maio) AS maio,
        SUM(temp_results.junho) AS junho,
        SUM(temp_results.julho) AS julho,
        SUM(temp_results.agosto) AS agosto,
        SUM(temp_results.setembro) AS setembro,
        SUM(temp_results.outubro) AS outubro,
        SUM(temp_results.novembro) AS novembro,
        SUM(temp_results.dezembro) AS dezembro,
        SUM(temp_results.total) AS total
    FROM temp_results
    GROUP BY 
        temp_results.ano, 
        temp_results.regiao_codigo, 
        temp_results.empresa_codigo, 
        temp_results.empresa_nome, 
        temp_results.empresa_nome_simplificado
	 ORDER BY 
	    temp_results.ano, temp_results.empresa_codigo;

    -- Optional: Clean up the temporary table after the function is done (it's automatically dropped at the end of the session)
    DROP TABLE IF EXISTS temp_results;
END;
$$;


ALTER FUNCTION concessao.bod_meses_pivot_array(p_ano integer, p_regiao_codigo text, p_colunas text[]) OWNER TO metroplan;

--
-- Name: bod_meses_pivot_array_ratio(integer, text, text[], text[]); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.bod_meses_pivot_array_ratio(p_ano integer, p_regiao text, p_array1 text[], p_array2 text[]) RETURNS TABLE(ano integer, regiao_codigo text, empresa_codigo text, empresa_nome text, empresa_nome_simplificado text, janeiro numeric, fevereiro numeric, marco numeric, abril numeric, maio numeric, junho numeric, julho numeric, agosto numeric, setembro numeric, outubro numeric, novembro numeric, dezembro numeric, total numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH query1 AS (
        -- First query: bod_meses_pivot_array
        SELECT *
        FROM concessao.bod_meses_pivot_array(
            p_ano, 
            p_regiao, 
            p_array1
        )
    ),
    query2 AS (
        -- Second query: bod_meses_pivot_array
        SELECT *
        FROM concessao.bod_meses_pivot_array(
            p_ano, 
            p_regiao, 
            p_array2
        )
    )
    SELECT 
        q1.ano,
        q1.regiao_codigo,
        q1.empresa_codigo,
        q1.empresa_nome,
        q1.empresa_nome_simplificado,
        COALESCE(COALESCE(q1.janeiro, 0) / NULLIF(q2.janeiro, 0), 0) AS janeiro,
        COALESCE(COALESCE(q1.fevereiro, 0) / NULLIF(q2.fevereiro, 0), 0) AS fevereiro,
        COALESCE(COALESCE(q1.marco, 0) / NULLIF(q2.marco, 0), 0) AS marco,
        COALESCE(COALESCE(q1.abril, 0) / NULLIF(q2.abril, 0), 0) AS abril,
        COALESCE(COALESCE(q1.maio, 0) / NULLIF(q2.maio, 0), 0) AS maio,
        COALESCE(COALESCE(q1.junho, 0) / NULLIF(q2.junho, 0), 0) AS junho,
        COALESCE(COALESCE(q1.julho, 0) / NULLIF(q2.julho, 0), 0) AS julho,
        COALESCE(COALESCE(q1.agosto, 0) / NULLIF(q2.agosto, 0), 0) AS agosto,
        COALESCE(COALESCE(q1.setembro, 0) / NULLIF(q2.setembro, 0), 0) AS setembro,
        COALESCE(COALESCE(q1.outubro, 0) / NULLIF(q2.outubro, 0), 0) AS outubro,
        COALESCE(COALESCE(q1.novembro, 0) / NULLIF(q2.novembro, 0), 0) AS novembro,
        COALESCE(COALESCE(q1.dezembro, 0) / NULLIF(q2.dezembro, 0), 0) AS dezembro,
        COALESCE(COALESCE(q1.total, 0) / NULLIF(q2.total, 0), 0) AS total
    FROM query1 q1
    JOIN query2 q2
    ON q1.ano = q2.ano
       AND q1.regiao_codigo = q2.regiao_codigo
       AND q1.empresa_codigo = q2.empresa_codigo;
END;
$$;


ALTER FUNCTION concessao.bod_meses_pivot_array_ratio(p_ano integer, p_regiao text, p_array1 text[], p_array2 text[]) OWNER TO metroplan;

--
-- Name: bod_soma_passageiros(integer, integer); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.bod_soma_passageiros(p_mes integer, p_ano integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    result INT;
BEGIN
    -- The following query sums the different 'passageiro' types for the given month and year
    SELECT COALESCE(SUM(passageiros_comum + passageiros_escolar + passageiros_passe_livre + 
                        passageiros_isentos + passageiros_integracao_rodoviaria + 
                        passageiros_integracao_ferroviaria), 0)
    INTO result
    FROM concessao.bod
    WHERE ano = p_ano
      AND mes = p_mes;

    -- Return the result, which is the sum of all passengers for the given month
    RETURN result;
END;
$$;


ALTER FUNCTION concessao.bod_soma_passageiros(p_mes integer, p_ano integer) OWNER TO metroplan;

--
-- Name: bod_soma_passageiros_regiao(integer, integer, text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.bod_soma_passageiros_regiao(p_mes integer, p_ano integer, p_regiao_codigo text) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    result INT;
BEGIN
    -- The following query sums the different 'passageiro' types for the given month, year, and region
    SELECT COALESCE(SUM(b.passageiros_comum + b.passageiros_escolar + b.passageiros_passe_livre + 
                        b.passageiros_isentos + b.passageiros_integracao_rodoviaria + 
                        b.passageiros_integracao_ferroviaria), 0)
    INTO result
    FROM concessao.bod b
    JOIN geral.empresa_codigo e ON b.empresa_codigo = e.codigo
    WHERE b.ano = p_ano
      AND b.mes = p_mes
      AND e.regiao_codigo = p_regiao_codigo;

    -- Return the result, which is the sum of all passengers for the given month and region
    RETURN result;
END;
$$;


ALTER FUNCTION concessao.bod_soma_passageiros_regiao(p_mes integer, p_ano integer, p_regiao_codigo text) OWNER TO metroplan;

--
-- Name: cabecalho_linha_hidroviario_site(text, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.cabecalho_linha_hidroviario_site(linha_codigo text, data date) RETURNS TABLE(linha_codigo text, linha_nome text, empresa_codigo text, empresa_nome text, via text, linha_modalidade_nome text, terminal_ida text, terminal_volta text, linha_suspensa boolean, municipio_nome_origem text, municipio_nome_destino text, mes_inicio integer, dia_inicio integer)
    LANGUAGE sql IMMUTABLE
    AS $_$

 SELECT linha_hidroviario.codigo AS linha_codigo, linha_hidroviario.nome AS linha_nome, empresa_codigo_hidroviario.codigo AS empresa_codigo, 
 empresa_hidroviario.nome AS empresa_nome, linha_hidroviario.via, linha_hidroviario.linha_modalidade_nome, linha_hidroviario.terminal_ida, linha_hidroviario.terminal_volta, 
        CASE
            WHEN (linha_hidroviario.data_exclusao IS NULL OR linha_hidroviario.data_exclusao > $2) and concessao.tem_horario_hidroviario($1, $2) THEN false
            ELSE true
        END AS linha_suspensa, linha_hidroviario.municipio_nome_origem, linha_hidroviario.municipio_nome_destino,
	case when concessao.tem_horario_hidroviario($1, $2) then null else (select mes_inicio from concessao.retorno_horarios_hidroviario($1, $2))
	end as mes_inicio,
	case when concessao.tem_horario_hidroviario($1, $2) then null else (select dia_inicio from concessao.retorno_horarios_hidroviario($1, $2))
	end as dia_inicio
        
   FROM concessao.empresa_hidroviario
   JOIN concessao.empresa_codigo_hidroviario ON empresa_codigo_hidroviario.empresa_hidroviario_cnpj = empresa_hidroviario.cnpj
   JOIN concessao.linha_hidroviario ON linha_hidroviario.empresa_codigo_hidroviario_codigo = empresa_codigo_hidroviario.codigo
   LEFT JOIN concessao.ordem_servico_hidroviario__linha_hidroviario ON linha_hidroviario.codigo = ordem_servico_hidroviario__linha_hidroviario.linha_hidroviario_codigo
   LEFT JOIN concessao.ordem_servico_hidroviario ON ordem_servico_hidroviario.numero = ordem_servico_hidroviario__linha_hidroviario.ordem_servico_hidroviario_numero
   where geral.intersecta_exclusao(linha_hidroviario.data_inclusao::date, linha_hidroviario.data_exclusao::date, $2, $2)
			and linha_hidroviario_codigo = $1
			order by linha_hidroviario.data_inclusao::date desc
			limit 1;

$_$;


ALTER FUNCTION concessao.cabecalho_linha_hidroviario_site(linha_codigo text, data date) OWNER TO metroplan;

--
-- Name: cabecalho_linha_site(text, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.cabecalho_linha_site(linha_codigo text, data date) RETURNS TABLE(linha_codigo text, linha_nome text, empresa_codigo text, empresa_nome text, via text, linha_modalidade_nome text, terminal_ida text, terminal_volta text, linha_suspensa boolean, municipio_nome_origem text, municipio_nome_destino text, mes_inicio integer, dia_inicio integer)
    LANGUAGE sql IMMUTABLE
    AS $_$

 SELECT linha.codigo AS linha_codigo, linha.nome AS linha_nome, empresa_codigo.codigo AS empresa_codigo, 
 empresa.nome AS empresa_nome, linha.via, linha.linha_modalidade_nome, linha.terminal_ida, linha.terminal_volta, 
        CASE
            WHEN (linha.data_exclusao IS NULL OR linha.data_exclusao > $2) and concessao.tem_horario($1, $2) THEN false
            ELSE true
        END AS linha_suspensa, linha.municipio_nome_origem, linha.municipio_nome_destino,
	case when concessao.tem_horario($1, $2) then null else (select mes_inicio from concessao.retorno_horarios($1, $2))
	end as mes_inicio,
	case when concessao.tem_horario($1, $2) then null else (select dia_inicio from concessao.retorno_horarios($1, $2))
	end as dia_inicio
        
   FROM geral.empresa
   JOIN geral.empresa_codigo ON empresa_codigo.empresa_cnpj = empresa.cnpj
   JOIN concessao.linha ON linha.empresa_codigo_codigo = empresa_codigo.codigo
   LEFT JOIN concessao.ordem_servico__linha ON linha.codigo = ordem_servico__linha.linha_codigo
   LEFT JOIN concessao.ordem_servico ON ordem_servico.numero = ordem_servico__linha.ordem_servico_numero
   where geral.intersecta_exclusao(linha.data_inclusao::date, linha.data_exclusao::date, $2, $2)
			and linha_codigo = $1
			order by linha.data_inclusao::date desc
			limit 1;

$_$;


ALTER FUNCTION concessao.cabecalho_linha_site(linha_codigo text, data date) OWNER TO metroplan;

--
-- Name: formata_ata_cetm(text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.formata_ata_cetm(codigo text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	
	select substr($1, 1, 4) || '/' || substr($1, 5, 6)

$_$;


ALTER FUNCTION concessao.formata_ata_cetm(codigo text) OWNER TO metroplan;

--
-- Name: formata_numero(text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.formata_numero(num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	
	select substr($1, 1, 3) || '/' || substr($1, 4, 2)

$_$;


ALTER FUNCTION concessao.formata_numero(num text) OWNER TO metroplan;

--
-- Name: formata_os(text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.formata_os(codigo text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	
	select substr($1, 1, 4) || '/' || substr($1, 5, 6)

$_$;


ALTER FUNCTION concessao.formata_os(codigo text) OWNER TO metroplan;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: horario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.horario (
    horario_id integer NOT NULL,
    linha_codigo text NOT NULL,
    horario time without time zone,
    ida boolean,
    sabado boolean,
    domingo_feriado boolean,
    observacoes character varying,
    apdf boolean,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    dia_inicio integer DEFAULT 1,
    mes_inicio integer DEFAULT 1,
    dia_fim integer DEFAULT 31,
    mes_fim integer DEFAULT 12
);


ALTER TABLE concessao.horario OWNER TO metroplan;

--
-- Name: horarios_escopo(text, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.horarios_escopo(text, date, date) RETURNS SETOF concessao.horario
    LANGUAGE sql
    AS $_$
    SELECT * from concessao.horario where
    linha_codigo = $1 and (
    (data_inclusao between $2 and $3) or
    (data_exclusao between $2 and $3) or
    ($2 between data_inclusao and data_exclusao) or
    ($3 between data_inclusao and data_exclusao) or
    (data_exclusao is null and $3 > data_inclusao))
    
$_$;


ALTER FUNCTION concessao.horarios_escopo(text, date, date) OWNER TO metroplan;

--
-- Name: horarios_escopo(character varying, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.horarios_escopo(character varying, date, date) RETURNS SETOF concessao.horario
    LANGUAGE sql
    AS $_$
    SELECT * from concessao.horario where
    linha_codigo = $1 and (
    (data_inclusao between $2 and $3) or
    (data_exclusao between $2 and $3) or
    ($2 between data_inclusao and data_exclusao) or
    ($3 between data_inclusao and data_exclusao) or
    (data_exclusao is null and $3 > data_inclusao))
    
$_$;


ALTER FUNCTION concessao.horarios_escopo(character varying, date, date) OWNER TO metroplan;

--
-- Name: intersecta_os(date, date, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.intersecta_os(data_vigencia date, data_validade date, data_inicio date, data_fim date) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
--true se os pares de datas intersectam
--a segunda data de cada par pode ser nula, valendo como 'para sempre'
--se a terceira e quarta foram nulas mas a primeira nao, return true


--$2 > $3 ao inves de $2 >= $3 porque o dia exato da data de exclusao ($2) não bate, pois naquele dia ela já não está valendo
--já $4 >= $1 não virou $4 > $1 porque o $4 nao é data de exclusao, é fim de periodo que foi selecionado, entao aquele dia vale

	select ($1 <= $3 and ($2 is null or $2 >= $3)) or ($3 <= $1 and ($4 is null or $4 >= $1))
		or ($3 is null and $4 is null and $1 is not null)


        
$_$;


ALTER FUNCTION concessao.intersecta_os(data_vigencia date, data_validade date, data_inicio date, data_fim date) OWNER TO metroplan;

--
-- Name: itinerario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.itinerario (
    itinerario_id integer NOT NULL,
    ordem integer NOT NULL,
    ida boolean NOT NULL,
    linha_codigo text,
    logradouro_nome text NOT NULL,
    municipio_nome text,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    secao boolean DEFAULT false NOT NULL,
    logradouro_tipo text
);


ALTER TABLE concessao.itinerario OWNER TO metroplan;

--
-- Name: COLUMN itinerario.logradouro_nome; Type: COMMENT; Schema: concessao; Owner: metroplan
--

COMMENT ON COLUMN concessao.itinerario.logradouro_nome IS 'NÃO ESTÁ LINKADO A logradouro AINDA!';


--
-- Name: COLUMN itinerario.secao; Type: COMMENT; Schema: concessao; Owner: metroplan
--

COMMENT ON COLUMN concessao.itinerario.secao IS 'renomear para secao_tarifaria?';


--
-- Name: itinerarios_escopo(text, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.itinerarios_escopo(text, date, date) RETURNS SETOF concessao.itinerario
    LANGUAGE sql
    AS $_$
    SELECT * from concessao.itinerario where
    linha_codigo = $1 and (
    (data_inclusao between $2 and $3) or
    (data_exclusao between $2 and $3) or
    ($2 between data_inclusao and data_exclusao) or
    ($3 between data_inclusao and data_exclusao) or
    (data_exclusao is null and $3 > data_inclusao))
    
$_$;


ALTER FUNCTION concessao.itinerarios_escopo(text, date, date) OWNER TO metroplan;

--
-- Name: itinerarios_escopo(character varying, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.itinerarios_escopo(character varying, date, date) RETURNS SETOF concessao.itinerario
    LANGUAGE sql
    AS $_$
    SELECT * from concessao.itinerario where
    linha_codigo = $1 and (
    (data_inclusao between $2 and $3) or
    (data_exclusao between $2 and $3) or
    ($2 between data_inclusao and data_exclusao) or
    ($3 between data_inclusao and data_exclusao) or
    (data_exclusao is null and $3 > data_inclusao))
    
$_$;


ALTER FUNCTION concessao.itinerarios_escopo(character varying, date, date) OWNER TO metroplan;

--
-- Name: kilometragem_regiao(date, date, text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.kilometragem_regiao(_inicio date, _fim date, _regiao text) RETURNS TABLE(empresa text, linha text, km integer, qt_util integer, tot_util integer, qt_sab integer, tot_sab integer, qt_dom integer, tot_dom integer, tot_hor_mes integer, tot_km_mes integer, ida boolean, magic text)
    LANGUAGE plpgsql
    AS $$
declare
clinha refcursor;
rlinha record;
_magic text;
qt_util integer;
tot_util integer;
qt_sab integer;
tot_sab integer;
qt_dom integer;
tot_dom integer;
tot_hor_mes integer;
tot_km_mes integer;
_ida boolean;
_km float;
begin

	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(	empresa text,
		tlinha text,
		km integer, 
		qt_util integer, tot_util integer, 
		qt_sab integer, tot_sab integer, 
		qt_dom integer, tot_dom integer, 
		tot_hor_mes integer, 
		tot_km_mes integer,
		ida boolean, magic text
	)
	ON COMMIT DROP;

	DROP TABLE IF EXISTS l;
	CREATE TEMP TABLE l
	(
		__emp text,
		__linha text
	)
	ON COMMIT DROP;


	insert into l (__emp, __linha) (select empresa_codigo_codigo, linha.codigo from concessao.linha, geral.empresa_codigo where empresa_codigo.regiao_codigo = _regiao and linha.empresa_codigo_codigo = empresa_codigo.codigo
		and geral.intersecta_exclusao(linha.data_inclusao::date, linha.data_exclusao::date, _inicio, _fim)
		order by linha.codigo);
	
	

	open clinha for select l.* from l;
	loop
		fetch clinha into rlinha;
		exit when not found;

		_ida := true;
		
		qt_util := (select sum(case when sabado = false and domingo_feriado = false then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and horario.ida = _ida);

		qt_sab := (select sum(case when sabado = true then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and horario.ida = _ida);

		qt_dom := (select sum(case when domingo_feriado = true then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and horario.ida = _ida);


		tot_util := qt_util * geral.conta_dias_uteis(_inicio, _fim);

		tot_sab := qt_sab * geral.conta_sabados(_inicio, _fim);

		tot_dom := qt_dom * geral.conta_domingos(_inicio, _fim);

		tot_hor_mes := tot_util + tot_sab + tot_dom;
		

		if _ida = true then
			_km := (select extensao_1a from concessao.linha where codigo = rlinha.__linha);
			tot_km_mes := round((select extensao_1a from concessao.linha where codigo = rlinha.__linha)::float * tot_hor_mes);
		else 
			_km := (select extensao_2a from concessao.linha where codigo = rlinha.__linha);
			tot_km_mes := round((select extensao_2a from concessao.linha where codigo = rlinha.__linha)::float * tot_hor_mes);
		end if;

		_magic := (select nome from geral.empresa, geral.empresa_codigo where empresa_codigo.codigo = rlinha.__emp and empresa_codigo.empresa_cnpj = empresa.cnpj);
		_magic := _magic || ' - Sentido 1 (ida)';

		if tot_km_mes is not null and tot_km_mes > 0 then
			insert into t (empresa, tlinha, km, qt_util, tot_util, qt_sab, tot_sab, qt_dom, tot_dom, tot_hor_mes, tot_km_mes, ida, magic) 
			values (rlinha.__emp, rlinha.__linha, _km, qt_util, tot_util, qt_sab, tot_sab, qt_dom, tot_dom, tot_hor_mes, tot_km_mes, _ida, _magic);
		end if;
		
		_ida := false;
		
		qt_util := (select sum(case when sabado = false and domingo_feriado = false then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and horario.ida = _ida);

		qt_sab := (select sum(case when sabado = true then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and horario.ida = _ida);

		qt_dom := (select sum(case when domingo_feriado = true then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and horario.ida = _ida);


		tot_util := qt_util * geral.conta_dias_uteis(_inicio, _fim);

		tot_sab := qt_sab * geral.conta_sabados(_inicio, _fim);

		tot_dom := qt_dom * geral.conta_domingos(_inicio, _fim);

		tot_hor_mes := tot_util + tot_sab + tot_dom;
		

		if _ida = true then
			_km := (select extensao_1a from concessao.linha where codigo = rlinha.__linha);
			tot_km_mes := round((select extensao_1a from concessao.linha where codigo = rlinha.__linha)::float * tot_hor_mes);
		else 
			_km := (select extensao_2a from concessao.linha where codigo = rlinha.__linha);
			tot_km_mes := round((select extensao_2a from concessao.linha where codigo = rlinha.__linha)::float * tot_hor_mes);
		end if;

		_magic := (select nome from geral.empresa, geral.empresa_codigo where empresa_codigo.codigo = rlinha.__emp and empresa_codigo.empresa_cnpj = empresa.cnpj);
		_magic := _magic || ' - Sentido 2 (volta)';

		if tot_km_mes is not null and tot_km_mes > 0 then
			insert into t (empresa, tlinha, km, qt_util, tot_util, qt_sab, tot_sab, qt_dom, tot_dom, tot_hor_mes, tot_km_mes, ida, magic) 
			values (rlinha.__emp, rlinha.__linha, _km, qt_util, tot_util, qt_sab, tot_sab, qt_dom, tot_dom, tot_hor_mes, tot_km_mes, _ida, _magic);
		end if;
		
	end loop;

	return query select * from t order by empresa, ida desc, linha;

end
$$;


ALTER FUNCTION concessao.kilometragem_regiao(_inicio date, _fim date, _regiao text) OWNER TO metroplan;

--
-- Name: kilometragem_regiao(boolean, date, date, text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.kilometragem_regiao(_ida boolean, _inicio date, _fim date, _regiao text) RETURNS TABLE(empresa text, linha text, qt_util integer, tot_util integer, qt_sab integer, tot_sab integer, qt_dom integer, tot_dom integer, tot_hor_mes integer, tot_km_mes integer)
    LANGUAGE plpgsql
    AS $$
declare
clinha refcursor;
rlinha record;

qt_util integer;
tot_util integer;
qt_sab integer;
tot_sab integer;
qt_dom integer;
tot_dom integer;
tot_hor_mes integer;
tot_km_mes integer;

begin

	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(	empresa text,
		tlinha text, 
		qt_util integer, tot_util integer, 
		qt_sab integer, tot_sab integer, 
		qt_dom integer, tot_dom integer, 
		tot_hor_mes integer, 
		tot_km_mes integer
	)
	ON COMMIT DROP;

	DROP TABLE IF EXISTS l;
	CREATE TEMP TABLE l
	(
		__emp text,
		__linha text
	)
	ON COMMIT DROP;


	insert into l (__emp, __linha) (select empresa_codigo_codigo, linha.codigo from concessao.linha, geral.empresa_codigo where empresa_codigo.regiao_codigo = _regiao and linha.empresa_codigo_codigo = empresa_codigo.codigo
		and geral.intersecta_exclusao(linha.data_inclusao::date, linha.data_exclusao::date, _inicio, _fim)
		order by linha.codigo);
	
	

	open clinha for select l.* from l;
	loop
		fetch clinha into rlinha;
		exit when not found;
		qt_util := (select sum(case when sabado = false and domingo_feriado = false then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and ida = _ida);

		qt_sab := (select sum(case when sabado = true then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and ida = _ida);


		qt_dom := (select sum(case when domingo_feriado = true then 1 else 0 end) from concessao.horario where linha_codigo = rlinha.__linha
			and geral.intersecta_exclusao(horario.data_inclusao::date, horario.data_exclusao::date, _inicio, _fim)
			and geral.intersecta_periodo(_inicio, _fim, mes_inicio, dia_inicio, mes_fim, dia_fim) and ida = _ida);



		tot_util := qt_util * geral.conta_dias_uteis(_inicio, _fim);

		tot_sab := qt_sab * geral.conta_sabados(_inicio, _fim);

		tot_dom := qt_dom * geral.conta_domingos(_inicio, _fim);

		tot_hor_mes := tot_util + tot_sab + tot_dom;
		

		if _ida = true then
			tot_km_mes := round((select extensao_1a from concessao.linha where codigo = rlinha.__linha)::float * tot_hor_mes);
		else 
			tot_km_mes := round((select extensao_2a from concessao.linha where codigo = rlinha.__linha)::float * tot_hor_mes);
		end if;

		insert into t (empresa, tlinha, qt_util, tot_util, qt_sab, tot_sab, qt_dom, tot_dom, tot_hor_mes, tot_km_mes) 
		values (rlinha.__emp, rlinha.__linha, qt_util, tot_util, qt_sab, tot_sab, qt_dom, tot_dom, tot_hor_mes, tot_km_mes);
		
		
	end loop;

	return query select * from t order by empresa, linha;

end
$$;


ALTER FUNCTION concessao.kilometragem_regiao(_ida boolean, _inicio date, _fim date, _regiao text) OWNER TO metroplan;

--
-- Name: nome_simplificado_empresa_pela_linha(text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.nome_simplificado_empresa_pela_linha(codigo text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
	select empresa.nome_simplificado from geral.empresa, geral.empresa_codigo, concessao.linha
	where empresa.cnpj = empresa_codigo.empresa_cnpj and linha.empresa_codigo_codigo = empresa_codigo.codigo
	and linha.codigo = $1
	

$_$;


ALTER FUNCTION concessao.nome_simplificado_empresa_pela_linha(codigo text) OWNER TO metroplan;

--
-- Name: numero_observacao_horario(integer, text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.numero_observacao_horario(integer, text) RETURNS text
    LANGUAGE sql
    AS $_$
select numero_obs from (select horario_id,
	(case when observacoes is not null and observacoes <> '' then sum((observacoes is not null and observacoes <> '')::integer) 
	over (order by not ida, domingo_feriado, sabado, horario) else null end)::text as numero_obs
	from concessao.horario
	where linha_codigo = $2
	and geral.ativo(data_inclusao::date, data_exclusao::date)
	order by horario) as q 
where horario_id = $1
$_$;


ALTER FUNCTION concessao.numero_observacao_horario(integer, text) OWNER TO metroplan;

--
-- Name: observacoes_numeradas(text, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.observacoes_numeradas(linha_codigo text, data_inicio date, data_fim date) RETURNS TABLE(obs text, numero integer)
    LANGUAGE sql
    AS $_$
select observacoes, 
(case when observacoes is not null and observacoes <> '' then sum((observacoes is not null and observacoes <> '')::integer) 
over ( order by observacoes ) else null end)::integer from concessao.horario_com_verao where observacoes is not null and observacoes <> '' 
--and geral.ativo(data_inclusao::date, data_exclusao::date)
and geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $3)
and geral.intersecta_periodo($2, $3, mes_inicio, dia_inicio, mes_fim, dia_fim)

and linha_codigo = $1 
group by observacoes;

$_$;


ALTER FUNCTION concessao.observacoes_numeradas(linha_codigo text, data_inicio date, data_fim date) OWNER TO metroplan;

--
-- Name: observacoes_numeradas_hidroviario(text, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.observacoes_numeradas_hidroviario(linha_codigo text, data_inicio date, data_fim date) RETURNS TABLE(obs text, numero integer)
    LANGUAGE sql
    AS $_$
select observacoes, 
(case when observacoes is not null and observacoes <> '' then sum((observacoes is not null and observacoes <> '')::integer) 
over ( order by observacoes ) else null end)::integer from concessao.horario_hidroviario where observacoes is not null and observacoes <> '' 
and geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $3)
and linha_hidroviario_codigo = $1 
group by observacoes;

$_$;


ALTER FUNCTION concessao.observacoes_numeradas_hidroviario(linha_codigo text, data_inicio date, data_fim date) OWNER TO metroplan;

--
-- Name: observacoes_numeradas_verao(text, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.observacoes_numeradas_verao(linha_codigo text, data_inicio date, data_fim date) RETURNS TABLE(obs text, numero integer)
    LANGUAGE sql
    AS $_$
select observacoes, 
(case when observacoes is not null and observacoes <> '' then sum((observacoes is not null and observacoes <> '')::integer) 
over ( order by observacoes ) else null end)::integer from concessao.horario_verao where observacoes is not null and observacoes <> '' 
--and geral.ativo(data_inclusao::date, data_exclusao::date)
and geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $3)
and geral.intersecta_periodo($2, $3, mes_inicio, dia_inicio, mes_fim, dia_fim)

and linha_codigo = $1 
group by observacoes;

$_$;


ALTER FUNCTION concessao.observacoes_numeradas_verao(linha_codigo text, data_inicio date, data_fim date) OWNER TO metroplan;

--
-- Name: pega_cnpj_pelo_codigo(text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.pega_cnpj_pelo_codigo(codigo text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	select empresa_cnpj from geral.empresa_codigo where codigo = $1;

$_$;


ALTER FUNCTION concessao.pega_cnpj_pelo_codigo(codigo text) OWNER TO metroplan;

--
-- Name: pega_codigo_pelo_cnpj(text); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.pega_codigo_pelo_cnpj(cnpj text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	
	select codigo from geral.empresa_codigo where empresa_cnpj = $1;

$_$;


ALTER FUNCTION concessao.pega_codigo_pelo_cnpj(cnpj text) OWNER TO metroplan;

--
-- Name: proxima_ordem_servico(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.proxima_ordem_servico() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare 
num text;
begin
	num := (select ((substring(numero from 1 for length(numero)-2))::int+1)::text from concessao.ordem_servico
		where numero is not null and
		substring(numero from '..$') = to_char(now(), 'yy')
		order by substring(numero from 1 for length(numero)-2) desc
		limit 1);

	if num is null then
		num := '0001';
	end if;		

	num := num || to_char(now(), 'yy');
	if length(num) < 6 then
		num := lpad(num, 6, '0');
	end if;

	
	
	return num;

end;
$_$;


ALTER FUNCTION concessao.proxima_ordem_servico() OWNER TO metroplan;

--
-- Name: proxima_ordem_servico_hidroviario(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.proxima_ordem_servico_hidroviario() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare 
num text;
begin
	num := (select ((substring(numero from 1 for length(numero)-2))::int+1)::text from concessao.ordem_servico_hidroviario
		where numero is not null and
		substring(numero from '..$') = to_char(now(), 'yy')
		order by substring(numero from 1 for length(numero)-2) desc
		limit 1);

	if num is null then
		num := '0001';
	end if;		

	num := num || to_char(now(), 'yy');
	if length(num) < 6 then
		num := lpad(num, 6, '0');
	end if;

	
	
	return num;

end;
$_$;


ALTER FUNCTION concessao.proxima_ordem_servico_hidroviario() OWNER TO metroplan;

--
-- Name: registrar_historico_linha(integer); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.registrar_historico_linha(p_linha_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE 
    current_data RECORD;
    last_checksum TEXT;
    new_checksum TEXT;
BEGIN
    -- Lock the linha to prevent concurrent registra() for the same linha
    PERFORM 1
    FROM concessao.linha
    WHERE id = p_linha_id
    FOR UPDATE;

    -- Get the latest historical row for this linha_id
    SELECT 
        md5(
            COALESCE(linha_codigo, '') || 
            COALESCE(linha_nome, '') || 
            COALESCE(empresa_codigo, '') || 
            COALESCE(empresa_nome, '') || 
            COALESCE(via, '') || 
            COALESCE(linha_modalidade_nome, '') || 
            COALESCE(terminal_ida, '') || 
            COALESCE(terminal_volta, '') || 
            COALESCE(extensao_1a, '0') || 
            COALESCE(extensao_1b, '0') || 
            COALESCE(extensao_2a, '0') || 
            COALESCE(extensao_2b, '0') || 
            COALESCE(extensao_3a, '0') || 
            COALESCE(extensao_3b, '0') || 
            COALESCE(tempo_viagem_1, '0') || 
            COALESCE(tempo_viagem_2, '0') || 
            COALESCE(tempo_viagem_3, '0') || 
            COALESCE(linha_situacao_nome, '') || 
            COALESCE(municipio_nome_origem, '') || 
            COALESCE(municipio_nome_destino, '') || 
            COALESCE(ordem_servico_numero, '') || 
            COALESCE(os_crua, '') || 
            COALESCE(data_emissao::TEXT, '') || 
            COALESCE(data_vigencia::TEXT, '') || 
            COALESCE(data_validade::TEXT, '') || 
            COALESCE(data_inclusao::TEXT, '') || 
            COALESCE(data_exclusao::TEXT, '') || 
            COALESCE(restricoes, '') || 
            COALESCE(observacoes, '') || 
            COALESCE(circular::TEXT, '') || 
            COALESCE(tarifa::TEXT, '')
        )
    INTO last_checksum
    FROM concessao.linha_historico 
    WHERE linha_id = p_linha_id
    ORDER BY data_historico_inicio DESC
    LIMIT 1;

    -- Fetch current data from various tables (unchanged)
    SELECT 
        l.id,
        l.codigo as linha_codigo,
        l.nome as linha_nome,
        ec.codigo AS empresa_codigo,  
        e.nome AS empresa_nome,  
        l.via,
        l.linha_modalidade_nome,
        l.terminal_ida,
        l.terminal_volta,
        l.extensao_1a,
        l.extensao_1b,
        l.extensao_2a,
        l.extensao_2b,
        l.extensao_3a,
        l.extensao_3b,
        l.tempo_viagem_1,
        l.tempo_viagem_2,
        l.tempo_viagem_3,
        concessao.status_linha(l.codigo, CURRENT_DATE, CURRENT_DATE) AS linha_situacao_nome,
        l.municipio_nome_origem,
        l.municipio_nome_destino,
        latest_os.ordem_servico_numero,
        latest_os.ordem_servico_numero AS os_crua,
        latest_os.data_emissao,
        latest_os.data_vigencia,
        latest_os.data_validade,
        l.data_inclusao,
        l.data_exclusao,
        l.restricoes,
        l.observacoes,
        l.circular,
        l.tarifa
    INTO current_data
    FROM concessao.linha l
    LEFT JOIN concessao.ordem_servico__linha osl ON l.codigo = osl.linha_codigo
    LEFT JOIN concessao.ordem_servico os ON osl.ordem_servico_numero = os.numero
    LEFT JOIN geral.empresa_codigo ec ON l.empresa_codigo_codigo = ec.codigo
    LEFT JOIN geral.empresa e ON ec.empresa_cnpj = e.cnpj
    LEFT JOIN LATERAL (
        SELECT os_linha.ordem_servico_numero, os.data_emissao, os.data_vigencia, os_linha.data_validade
        FROM concessao.ordem_servico__linha os_linha
        JOIN concessao.ordem_servico os ON os.numero = os_linha.ordem_servico_numero
        WHERE os_linha.linha_codigo = l.codigo
        ORDER BY os.data_emissao DESC
        LIMIT 1
    ) AS latest_os ON TRUE
    WHERE l.id = p_linha_id;

    -- Generate a new checksum for the current data (unchanged)
    SELECT 
        md5(
            COALESCE(current_data.linha_codigo, '') || 
            COALESCE(current_data.linha_nome, '') || 
            COALESCE(current_data.empresa_codigo, '') || 
            COALESCE(current_data.empresa_nome, '') || 
            COALESCE(current_data.via, '') || 
            COALESCE(current_data.linha_modalidade_nome, '') || 
            COALESCE(current_data.terminal_ida, '') || 
            COALESCE(current_data.terminal_volta, '') || 
            COALESCE(current_data.extensao_1a, '0') || 
            COALESCE(current_data.extensao_1b, '0') || 
            COALESCE(current_data.extensao_2a, '0') || 
            COALESCE(current_data.extensao_2b, '0') || 
            COALESCE(current_data.extensao_3a, '0') || 
            COALESCE(current_data.extensao_3b, '0') || 
            COALESCE(current_data.tempo_viagem_1, '0') || 
            COALESCE(current_data.tempo_viagem_2, '0') || 
            COALESCE(current_data.tempo_viagem_3, '0') || 
            COALESCE(current_data.linha_situacao_nome, '') || 
            COALESCE(current_data.municipio_nome_origem, '') || 
            COALESCE(current_data.municipio_nome_destino, '') || 
            COALESCE(current_data.ordem_servico_numero, '') || 
            COALESCE(current_data.os_crua, '') || 
            COALESCE(current_data.data_emissao::TEXT, '') || 
            COALESCE(current_data.data_vigencia::TEXT, '') || 
            COALESCE(current_data.data_validade::TEXT, '') || 
            COALESCE(current_data.data_inclusao::TEXT, '') || 
            COALESCE(current_data.data_exclusao::TEXT, '') || 
            COALESCE(current_data.restricoes, '') || 
            COALESCE(current_data.observacoes, '') || 
            COALESCE(current_data.circular::TEXT, '') || 
            COALESCE(current_data.tarifa::TEXT, ''))
    INTO new_checksum;

    -- Only insert a new row if the checksum is different
    IF last_checksum IS DISTINCT FROM new_checksum THEN

        -- Delete today's row only if a new row is actually needed
        DELETE FROM concessao.linha_historico 
        WHERE linha_id = p_linha_id 
        AND data_historico_inicio = CURRENT_DATE;

	    UPDATE concessao.linha_historico
	    SET data_historico_fim = CURRENT_DATE - INTERVAL '1 day'
	    WHERE linha_id = p_linha_id
	    AND data_historico_fim IS NULL;

        -- Insert new row (unchanged)
        INSERT INTO concessao.linha_historico (
            linha_id,
            linha_codigo,
            data_historico_inicio,
            data_historico_fim,
            linha_nome,
            empresa_codigo,
            empresa_nome,
            via,
            linha_modalidade_nome,
            terminal_ida,
            terminal_volta,
            extensao_1a,
            extensao_1b,
            extensao_2a,
            extensao_2b,
            extensao_3a,
            extensao_3b,
            tempo_viagem_1,
            tempo_viagem_2,
            tempo_viagem_3,
            linha_situacao_nome,
            municipio_nome_origem,
            municipio_nome_destino,
            ordem_servico_numero,
            os_crua,
            data_emissao,
            data_vigencia,
            data_validade,
            data_inclusao,
            data_exclusao,
            restricoes,
            observacoes,
            circular,
            tarifa
        ) VALUES (
            current_data.id,
            current_data.linha_codigo,
            current_date,  
            NULL,  
            current_data.linha_nome,
            current_data.empresa_codigo,
            current_data.empresa_nome,
            current_data.via,
            current_data.linha_modalidade_nome,
            current_data.terminal_ida,
            current_data.terminal_volta,
            current_data.extensao_1a,
            current_data.extensao_1b,
            current_data.extensao_2a,
            current_data.extensao_2b,
            current_data.extensao_3a,
            current_data.extensao_3b,
            current_data.tempo_viagem_1,
            current_data.tempo_viagem_2,
            current_data.tempo_viagem_3,
            current_data.linha_situacao_nome,
            current_data.municipio_nome_origem,
            current_data.municipio_nome_destino,
            current_data.ordem_servico_numero,
            current_data.os_crua,
            current_data.data_emissao,
            current_data.data_vigencia,
            current_data.data_validade,
            current_data.data_inclusao,
            current_data.data_exclusao,
            current_data.restricoes,
            current_data.observacoes,
            current_data.circular,
            current_data.tarifa
        );
    END IF;
END;
$$;


ALTER FUNCTION concessao.registrar_historico_linha(p_linha_id integer) OWNER TO metroplan;

--
-- Name: retorno_horarios(text, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.retorno_horarios(linha_codigo text, data date) RETURNS TABLE(dia_inicio integer, mes_inicio integer)
    LANGUAGE sql IMMUTABLE
    AS $_$

	select dia_inicio, mes_inicio from concessao.horario 
	where geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $2)
	and linha_codigo = $1
	and not geral.intersecta_periodo($2, $2, dia_inicio, mes_inicio, dia_fim, mes_fim)
	order by mes_inicio, dia_inicio limit 1

$_$;


ALTER FUNCTION concessao.retorno_horarios(linha_codigo text, data date) OWNER TO metroplan;

--
-- Name: retorno_horarios_hidroviario(text, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.retorno_horarios_hidroviario(linha_codigo text, data date) RETURNS TABLE(dia_inicio integer, mes_inicio integer)
    LANGUAGE sql IMMUTABLE
    AS $_$

	select dia_inicio, mes_inicio from concessao.horario_hidroviario 
	where geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $2)
	and linha_hidroviario_codigo = $1
	and not geral.intersecta_periodo($2, $2, dia_inicio, mes_inicio, dia_fim, mes_fim)
	order by mes_inicio, dia_inicio limit 1

$_$;


ALTER FUNCTION concessao.retorno_horarios_hidroviario(linha_codigo text, data date) OWNER TO metroplan;

--
-- Name: status_linha(text, date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.status_linha(p_linha_codigo text, p_data_inicio date, p_data_fim date) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
declare
tem_horario boolean;
nao_excluida boolean;
status text;
begin

	nao_excluida := (select geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, p_data_fim, p_data_fim)
		from concessao.linha where codigo = p_linha_codigo);
	
	if nao_excluida = false then
		return 'LINHA DESATIVADA';
	end if;
		

--    tem_horario := (select (count(*) > 0) as tem_horario from concessao.horario 
--    where geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $2) and
--    (geral.intersecta_periodo(p_data_inicio, p_data_inicio, mes_inicio, dia_inicio, mes_fim, dia_fim)
--        or geral.intersecta_periodo(p_data_fim, p_data_fim, mes_inicio, dia_inicio, mes_fim, dia_fim))
--    and linha_codigo = p_linha_codigo);

	tem_horario = concessao.tem_horario(p_linha_codigo, p_data_fim);

	if tem_horario then
		return 'LINHA OPERANDO';
	else
		return 'LINHA SUSPENSA';
	end if;


end;
$_$;


ALTER FUNCTION concessao.status_linha(p_linha_codigo text, p_data_inicio date, p_data_fim date) OWNER TO metroplan;

--
-- Name: tem_horario(text, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.tem_horario(linha_codigo text, data date) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$
	--repare que esta função compara uma data só. então só serev pro site
	--pros relatorios do sistema sempre temos duas datas
	select (count(*) > 0) as tem_horario from concessao.horario 
	where geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $2)
	and geral.intersecta_periodo($2, $2, mes_inicio, dia_inicio, mes_fim, dia_fim)
	and linha_codigo = $1

$_$;


ALTER FUNCTION concessao.tem_horario(linha_codigo text, data date) OWNER TO metroplan;

--
-- Name: tem_horario_hidroviario(text, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.tem_horario_hidroviario(linha_codigo text, data date) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$

	select (count(*) > 0) as tem_horario from concessao.horario_hidroviario 
	where geral.intersecta_exclusao(data_inclusao::date, data_exclusao::date, $2, $2)
	and geral.intersecta_periodo($2, $2, dia_inicio, mes_inicio, dia_fim, mes_fim)
	and linha_hidroviario_codigo = $1

$_$;


ALTER FUNCTION concessao.tem_horario_hidroviario(linha_codigo text, data date) OWNER TO metroplan;

--
-- Name: trigger_historico_linha_on_empresa_codigo(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.trigger_historico_linha_on_empresa_codigo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_codigo TEXT;
BEGIN
  -- Use COALESCE to get the empresa_codigo affected
  v_codigo := COALESCE(NEW.codigo, OLD.codigo);

  -- Perform the historical registration for the linhas affected by the empresa_codigo change
  PERFORM concessao.registrar_historico_linha(l.id)
  FROM concessao.linha l
  WHERE l.empresa_codigo_codigo = v_codigo;

  -- Return NEW for INSERT, UPDATE, and DELETE (you can return NEW in all cases)
  RETURN NEW;  -- For INSERT/UPDATE/DELETE, just return NEW
END;
$$;


ALTER FUNCTION concessao.trigger_historico_linha_on_empresa_codigo() OWNER TO metroplan;

--
-- Name: trigger_historico_linha_on_horario(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.trigger_historico_linha_on_horario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_codigo TEXT;
BEGIN
  -- Get the linha_codigo affected (NEW on insert/update, OLD on delete)
  v_codigo := COALESCE(NEW.linha_codigo, OLD.linha_codigo);

  -- Call registrar_historico_linha for the corresponding linha.id
  PERFORM concessao.registrar_historico_linha(l.id)
  FROM concessao.linha l
  WHERE l.codigo = v_codigo;

  RETURN NEW;
END;
$$;


ALTER FUNCTION concessao.trigger_historico_linha_on_horario() OWNER TO metroplan;

--
-- Name: trigger_historico_linha_on_linha(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.trigger_historico_linha_on_linha() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM concessao.registrar_historico_linha(NEW.id);
    RETURN NEW;
END;
$$;


ALTER FUNCTION concessao.trigger_historico_linha_on_linha() OWNER TO metroplan;

--
-- Name: trigger_historico_linha_on_ordem_servico(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.trigger_historico_linha_on_ordem_servico() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_numero TEXT;
  v_linha RECORD;
BEGIN
  -- Get the affected ordem_servico.numero (NEW for insert/update, OLD for delete)
  v_numero := COALESCE(NEW.numero, OLD.numero);

  -- For each linha_codigo linked to this ordem_servico.numero
  FOR v_linha IN
    SELECT l.id
    FROM concessao.ordem_servico__linha osl
    JOIN concessao.linha l ON osl.linha_codigo = l.codigo
    WHERE osl.ordem_servico_numero = v_numero
  LOOP
    -- Call registrar_historico_linha for that linha_id
    PERFORM concessao.registrar_historico_linha(v_linha.id);
  END LOOP;

  RETURN NEW;
END;
$$;


ALTER FUNCTION concessao.trigger_historico_linha_on_ordem_servico() OWNER TO metroplan;

--
-- Name: trigger_historico_linha_on_ordem_servico__linha(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.trigger_historico_linha_on_ordem_servico__linha() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_codigo TEXT;
BEGIN
  -- Get the linha_codigo affected
  v_codigo := COALESCE(NEW.linha_codigo, OLD.linha_codigo);

  -- Get linha_id from linha table
  PERFORM concessao.registrar_historico_linha(l.id)
  FROM concessao.linha l
  WHERE l.codigo = v_codigo;

  RETURN NEW;
END;
$$;


ALTER FUNCTION concessao.trigger_historico_linha_on_ordem_servico__linha() OWNER TO metroplan;

--
-- Name: trigger_registra_historico_por_empresa(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.trigger_registra_historico_por_empresa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    linha_id integer;
BEGIN
    -- Skip trigger if no relevant change
    IF ROW(NEW.*) IS NOT DISTINCT FROM ROW(OLD.*) THEN
        RETURN NEW;
    END IF;

    FOR linha_id IN
        SELECT l.id
        FROM concessao.linha l
        JOIN geral.empresa_codigo ec ON ec.codigo = l.empresa_codigo_codigo
        WHERE ec.empresa_cnpj = NEW.cnpj
    LOOP
        PERFORM concessao.registrar_historico_linha(linha_id);
    END LOOP;

    RETURN NEW;
END;
$$;


ALTER FUNCTION concessao.trigger_registra_historico_por_empresa() OWNER TO metroplan;

--
-- Name: upper_itinerario(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.upper_itinerario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	--quando a tabela logradouro estiver ativa, este trigger nao
	--sera necessario, sera usado geral.upper_nome() nela
	NEW.logradouro_nome = upper(trim(NEW.logradouro_nome));

	return NEW;
END;$$;


ALTER FUNCTION concessao.upper_itinerario() OWNER TO metroplan;

--
-- Name: upper_linha(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.upper_linha() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.nome = upper(trim(NEW.nome));
	NEW.via = upper(trim(NEW.via));
	NEW.restricoes = upper(trim(NEW.restricoes));
	NEW.observacoes = upper(trim(NEW.observacoes));
	NEW.codigo_daer = upper(trim(NEW.codigo_daer));
	NEW.codigo = upper(trim(NEW.codigo));
	NEW.terminal_ida = upper(trim(NEW.terminal_ida));
	NEW.terminal_volta = upper(trim(NEW.terminal_volta));

	return NEW;
END;$$;


ALTER FUNCTION concessao.upper_linha() OWNER TO metroplan;

--
-- Name: upper_linha_hidroviario(); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.upper_linha_hidroviario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.nome = upper(trim(NEW.nome));
	NEW.via = upper(trim(NEW.via));
	NEW.restricoes = upper(trim(NEW.restricoes));
	NEW.observacoes = upper(trim(NEW.observacoes));
	NEW.codigo = upper(trim(NEW.codigo));
	NEW.terminal_ida = upper(trim(NEW.terminal_ida));
	NEW.terminal_volta = upper(trim(NEW.terminal_volta));

	return NEW;
END;$$;


ALTER FUNCTION concessao.upper_linha_hidroviario() OWNER TO metroplan;

--
-- Name: veiculos_incluidos(date, date); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.veiculos_incluidos(data_inicio date, data_fim date) RETURNS TABLE(placa text, empresa_nome text, chassi_numero text, ano_inclusao integer, mes_inclusao integer, chassi_ano integer, idade integer, classificacao_inmetro text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        veiculo.placa,
        empresa.nome,
        veiculo.chassi_numero,
        extract(year from data_inclusao_concessao)::integer as ano_inclusao, 
        extract(month from data_inclusao_concessao)::integer as mes_inclusao, 
        veiculo.chassi_ano,
        extract(year from data_inclusao_concessao)::integer - veiculo.chassi_ano as idade,
		classificacao_inmetro_nome
    FROM geral.veiculo
    JOIN geral.empresa_codigo ON empresa_codigo_codigo = codigo
    JOIN geral.empresa ON empresa.cnpj = empresa_codigo.empresa_cnpj
    WHERE data_inclusao_concessao IS NOT NULL
    AND data_inclusao_concessao BETWEEN data_inicio AND data_fim;
END;
$$;


ALTER FUNCTION concessao.veiculos_incluidos(data_inicio date, data_fim date) OWNER TO metroplan;

--
-- Name: vencimento_chassi(integer); Type: FUNCTION; Schema: concessao; Owner: metroplan
--

CREATE FUNCTION concessao.vencimento_chassi(num integer) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $_$

	
	select (case when $1 = 1999 or  $1 = 2000 then 2017 when $1 = 2001 or $1 = 2002 then 2018 else $1 + 16 end)

$_$;


ALTER FUNCTION concessao.vencimento_chassi(num integer) OWNER TO metroplan;

--
-- Name: avancar_pendencia(integer, text, text, text); Type: FUNCTION; Schema: eventual; Owner: postgres
--

CREATE FUNCTION eventual.avancar_pendencia(p_fluxo_id integer, p_status text, p_analista text DEFAULT NULL::text, p_motivo text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_entidade_tipo text;
    v_entidade_id   text;
    ultimo          RECORD;
BEGIN
    -- Find referenced entity from the given fluxo row
    SELECT entidade_tipo, entidade_id
    INTO v_entidade_tipo, v_entidade_id
    FROM eventual.fluxo_pendencia
    WHERE id = p_fluxo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pendência id % not found', p_fluxo_id;
    END IF;

    -- Get last pendência for same entity
    SELECT *
    INTO ultimo
    FROM eventual.fluxo_pendencia
    WHERE entidade_tipo = v_entidade_tipo
      AND entidade_id   = v_entidade_id
    ORDER BY criado_em DESC
    LIMIT 1;

    -- -----------------------------------------
    -- SPECIAL LOGIC FOR EM_ANALISE
    -- -----------------------------------------
    IF ultimo.status = 'EM_ANALISE' AND p_status = 'EM_ANALISE' THEN

        IF ultimo.analista = p_analista THEN
            -- Same analista → no-op (silent success)
            RETURN;
        ELSE
            -- Different analista → explicit error
            RAISE EXCEPTION
                'Pendência already being analyzed by another analista: %',
                ultimo.analista;
        END IF;

    END IF;

    -- Otherwise, perform normal insert (triggers will validate)
    INSERT INTO eventual.fluxo_pendencia (
        entidade_tipo, entidade_id, status, analista, motivo
    )
    VALUES (v_entidade_tipo, v_entidade_id, p_status, p_analista, p_motivo);

    -- Sync entity status
    IF v_entidade_tipo = 'EMPRESA' THEN
        UPDATE geral.empresa
        SET eventual_status = p_status
        WHERE cnpj = v_entidade_id;

    ELSIF v_entidade_tipo = 'VEICULO' THEN
        UPDATE geral.veiculo
        SET eventual_status = p_status
        WHERE placa = v_entidade_id;

    ELSIF v_entidade_tipo = 'MOTORISTA' THEN
        UPDATE eventual.motorista
        SET eventual_status = p_status
        WHERE id::text = v_entidade_id;

    END IF;


END;
$$;


ALTER FUNCTION eventual.avancar_pendencia(p_fluxo_id integer, p_status text, p_analista text, p_motivo text) OWNER TO postgres;

--
-- Name: fn_analista_obrigatorio(); Type: FUNCTION; Schema: eventual; Owner: postgres
--

CREATE FUNCTION eventual.fn_analista_obrigatorio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- analista must be present whenever status is NOT AGUARDANDO_ANALISE
    IF NEW.status <> 'AGUARDANDO_ANALISE' THEN
        IF NEW.analista IS NULL OR btrim(NEW.analista) = '' THEN
            RAISE EXCEPTION 'analista cannot be NULL when status = %', NEW.status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION eventual.fn_analista_obrigatorio() OWNER TO postgres;

--
-- Name: fn_evitar_status_repetido(); Type: FUNCTION; Schema: eventual; Owner: postgres
--

CREATE FUNCTION eventual.fn_evitar_status_repetido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    ultimo RECORD;
BEGIN
    SELECT *
    INTO ultimo
    FROM eventual.fluxo_pendencia fp
    WHERE fp.entidade_tipo = NEW.entidade_tipo
      AND fp.entidade_id   = NEW.entidade_id
    ORDER BY fp.criado_em DESC
    LIMIT 1;

    IF ultimo IS NOT NULL THEN
        IF ultimo.status = NEW.status THEN
            RAISE EXCEPTION
                'Cannot insert duplicate status %. Last status for this pendência is already %.',
                NEW.status, ultimo.status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION eventual.fn_evitar_status_repetido() OWNER TO postgres;

--
-- Name: fn_motivo_obrigatorio(); Type: FUNCTION; Schema: eventual; Owner: postgres
--

CREATE FUNCTION eventual.fn_motivo_obrigatorio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- motivo required ONLY when rejecting
    IF NEW.status IN ('REJEITADO') THEN
        IF NEW.motivo IS NULL OR btrim(NEW.motivo) = '' THEN
            RAISE EXCEPTION 'motivo cannot be NULL or empty when status = %', NEW.status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION eventual.fn_motivo_obrigatorio() OWNER TO postgres;

--
-- Name: fn_valida_entidade(); Type: FUNCTION; Schema: eventual; Owner: postgres
--

CREATE FUNCTION eventual.fn_valida_entidade() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.entidade_tipo = 'EMPRESA' THEN
        IF NOT EXISTS (SELECT 1 FROM geral.empresa e WHERE e.cnpj::text = NEW.entidade_id) THEN
            RAISE EXCEPTION 'Entidade EMPRESA % does not exist', NEW.entidade_id;
        END IF;
    ELSIF NEW.entidade_tipo = 'VEICULO' THEN
        IF NOT EXISTS (SELECT 1 FROM geral.veiculo v WHERE v.placa = NEW.entidade_id) THEN
            RAISE EXCEPTION 'Entidade VEICULO % does not exist', NEW.entidade_id;
        END IF;
    ELSIF NEW.entidade_tipo = 'MOTORISTA' THEN
        IF NOT EXISTS (SELECT 1 FROM eventual.motorista m WHERE m.id::text = NEW.entidade_id) THEN
            RAISE EXCEPTION 'Entidade MOTORISTA % does not exist', NEW.entidade_id;
        END IF;
    ELSE
        RAISE EXCEPTION 'Unknown entidade_tipo: %', NEW.entidade_tipo;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION eventual.fn_valida_entidade() OWNER TO postgres;

--
-- Name: ajeita_servico(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.ajeita_servico(text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
declare

tmp text;
one text;
begin



tmp = $1;
tmp := substr(tmp, 5);
tmp := lower(tmp);
one := upper(substring(tmp, 1, 1));
tmp = one || substr(tmp, 2);

return tmp;
end;
$_$;


ALTER FUNCTION fretamento.ajeita_servico(text) OWNER TO metroplan;

--
-- Name: ano_fabricacao(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.ano_fabricacao(placa text) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$
	select ano_fabricacao from geral.veiculo where veiculo.placa = $1;
$_$;


ALTER FUNCTION fretamento.ano_fabricacao(placa text) OWNER TO metroplan;

--
-- Name: autorizacao_vencida(integer, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.autorizacao_vencida(contrato integer, placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT

--(select autorizacao.data_inicio + interval '1 year' from fretamento.autorizacao--, fretamento.contrato
--		--WHERE autorizacao.contrato_codigo = contrato.codigo and contrato.codigo = $1 and autorizacao.renovacao = false
--		--AND autorizacao.veiculo_placa = $2 order by autorizacao.data_inicio desc limit 1) < current_date
--		where autorizacao.veiculo_placa = $2 order by autorizacao.data_inicio desc limit 1) < current_date

--2025-09-11 acho que quebrei a funcção acima removendo o check de 'renovacao', porque tirei tambem o link com contrato
--entao possivelmente alguns checks davam true, indevidamente, por pegar uma data valida de outro contrato

(select autorizacao.data_inicio + interval '1 year' from fretamento.autorizacao, fretamento.contrato
		WHERE autorizacao.contrato_codigo = contrato.codigo and contrato.codigo = $1
		and autorizacao.veiculo_placa = $2 order by autorizacao.data_inicio desc limit 1) < current_date


$_$;


ALTER FUNCTION fretamento.autorizacao_vencida(contrato integer, placa text) OWNER TO metroplan;

--
-- Name: checa_autorizacao(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.checa_autorizacao(autorizacao text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

select (select * from fretamento.checa_tudo(
(select contrato_codigo from fretamento.autorizacao where codigo = $1),
(select veiculo_placa from fretamento.autorizacao where codigo = $1)
)) and ((select autorizacao.data_inicio + interval '1 year' from fretamento.autorizacao WHERE codigo = $1 ) > current_date)

$_$;


ALTER FUNCTION fretamento.checa_autorizacao(autorizacao text) OWNER TO metroplan;

--
-- Name: checa_contrato_site(integer, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.checa_contrato_site(contrato integer, placa text) RETURNS TABLE(empresa_nome text, placa text, contrato integer, contratante text, vencimento_contrato date, vencimento_autorizacao date, vencimento_laudo date, vencimento_documentacao date)
    LANGUAGE sql STABLE
    AS $_$


select empresa.nome as empresa_nome, veiculo.placa as placa, contrato.codigo as contrato,
contratante.nome as contratante, max(contrato.data_fim) as vencimento_contrato, 
(max(autorizacao.data_inicio) + interval '1 year')::date as vencimento_autorizacao,
max(laudo_vistoria.data_validade) as vencimento_laudo,
(max(empresa.data_entrega_documentacao) + interval '1 year')::date as vencimento_documentacao


from geral.empresa, geral.veiculo, fretamento.autorizacao, fretamento.laudo_vistoria, fretamento.contrato, fretamento.contratante
where veiculo.empresa_cnpj = empresa.cnpj and fretamento.autorizacao.contrato_codigo = contrato.codigo 
and contratante.codigo = contrato.contratante_codigo 
and contrato.codigo = $1 and veiculo.placa = $2
and autorizacao.veiculo_placa = veiculo.placa and laudo_vistoria.veiculo_placa = veiculo.placa

group by empresa_nome, placa, contrato, contratante

$_$;


ALTER FUNCTION fretamento.checa_contrato_site(contrato integer, placa text) OWNER TO metroplan;

--
-- Name: checa_crlv(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.checa_crlv(_placa text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
declare
_crlv integer;
_vencimento text;
begin

--esta função checa pela placa, para melhor performance geralmente deve-se usar a função que checa direto o numero crlv (fretamento.checa_crlv(text, integer))

_placa := upper(_placa);

_crlv := (select crlv from geral.veiculo where placa = _placa);

if _crlv is null then
	return false;
end if;

if '12345' like '%' || right(_placa, 1) || '%' then 
	_vencimento := '30/06/' || (_crlv+1)::text;
end if;
if '67890' like '%' || right(_placa, 1) || '%' then 
	_vencimento := '31/07/' || (_crlv+1)::text;
end if;

return (_vencimento::date >= current_date);

end;
$$;


ALTER FUNCTION fretamento.checa_crlv(_placa text) OWNER TO metroplan;

--
-- Name: checa_crlv(text, integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.checa_crlv(_placa text, _crlv integer) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
declare
_vencimento text;
begin

_placa := upper(_placa);

if _crlv is null then
	return false;
end if;

--if '12345' like '%' || right(_placa, 1) || '%' then 
--	_vencimento := '30/06/' || (_crlv+1)::text;
--end if;
--if '67890' like '%' || right(_placa, 1) || '%' then 
--	_vencimento := '31/07/' || (_crlv+1)::text;
--end if;

_vencimento := '31/07/' || (_crlv+1)::text;

return (_vencimento::date >= current_date);

end;
$$;


ALTER FUNCTION fretamento.checa_crlv(_placa text, _crlv integer) OWNER TO metroplan;

--
-- Name: checa_placa_site(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.checa_placa_site(placa text) RETURNS TABLE(placa text, contratante text, vencido boolean)
    LANGUAGE sql STABLE
    AS $_$


select veiculo.placa, contratante.nome, not ((select * from fretamento.checa_tudo(contrato.codigo, veiculo.placa))) as vencido
from geral.veiculo, fretamento.contrato, fretamento.contratante, fretamento.autorizacao
where autorizacao.contrato_codigo = contrato.codigo and contratante.codigo = contrato.contratante_codigo
and autorizacao.veiculo_placa = veiculo.placa
and veiculo.placa = $1
group by veiculo.placa, contratante.nome, data_fim, contrato.codigo
order by data_fim desc limit 1


$_$;


ALTER FUNCTION fretamento.checa_placa_site(placa text) OWNER TO metroplan;

--
-- Name: checa_tudo(integer, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.checa_tudo(contrato integer, placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$
SELECT not (
(coalesce((select * from fretamento.autorizacao_vencida($1, $2)), true) = true)
or
(coalesce((select * from fretamento.contrato_vencido($1, $2)), true) = true)
or
(coalesce((select * from fretamento.documentacao_vencida($2)), true) = true)
or
(coalesce((select * from fretamento.laudo_vencido($2)), true) = true)
or
(coalesce((select * from fretamento.processo_encerrado($2)), false) = true)
or
(coalesce((select * from fretamento.tem_divida($2)), false) = true)
or
(coalesce((select * from fretamento.veiculo_excluido($2)), false) = true)
or
(coalesce((select * from fretamento.empresa_excluida($2)), false) = true)
or
(coalesce((select * from fretamento.seguro_vencido($2)), true) = true)
or
(coalesce((select * from fretamento.emplacamento_ativo($2)), false) = true)
or
((select servico_nome is null from fretamento.contrato where codigo = $1) = true)
)

$_$;


ALTER FUNCTION fretamento.checa_tudo(contrato integer, placa text) OWNER TO metroplan;

--
-- Name: consulta_placa(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.consulta_placa(_placa text) RETURNS TABLE(placa text, vencimento_seguro date, vistoria_data date, contrato_codigo integer, contrato_vencimento date, validade_taxa date, empresa text)
    LANGUAGE plpgsql
    AS $$
declare 
len integer;
_contrato integer;
begin



	_contrato :=  fretamento.pega_contrato(_placa);
	
	return query select 
	_placa as placa,
	fretamento.veiculo_validade_seguro(_placa) as vencimento_seguro,
	fretamento.veiculo_validade_laudo(_placa) as vistoria_data, 
	_contrato as contrato_codigo,
	fretamento.veiculo_validade_contrato(_contrato) as contrato_vencimento,
	fretamento.veiculo_validade_autorizacao(_placa, _contrato) as validade_taxa,
	fretamento.nome_empresa_por_placa(_placa) as empresa;
	  


	 

end;
$$;


ALTER FUNCTION fretamento.consulta_placa(_placa text) OWNER TO metroplan;

--
-- Name: consulta_placa_site2(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.consulta_placa_site2(_placa text) RETURNS TABLE(placa text, vencimento_seguro date, vistoria_data date, contrato_codigo integer, contrato_vencimento date, validade_taxa date, empresa text, crlv integer)
    LANGUAGE plpgsql
    AS $$
declare

c refcursor;
r record;
seg date;
vis date;
tax date;
emp text;
crlv_ integer;
begin


	DROP TABLE IF EXISTS t;
	CREATE  TEMP TABLE if not exists t
	(
		placa text, 
		vencimento_seguro date, 
		vistoria_data date, 
		contrato_codigo integer, 
		contrato_vencimento date, 
		validade_taxa date, 
		empresa text,
		crlv integer
	)
	ON COMMIT DROP;


	seg := fretamento.veiculo_validade_seguro(_placa);
	vis := fretamento.veiculo_validade_laudo(_placa);
	tax := fretamento.veiculo_validade_autorizacao(_placa, fretamento.pega_contrato(_placa));
	emp := fretamento.nome_empresa_por_placa(_placa);
	crlv_ := (select veiculo.crlv from geral.veiculo where veiculo.placa = _placa);

	open c for select distinct contrato.codigo, contrato.data_fim from fretamento.contrato, fretamento.autorizacao, fretamento.contrato_itinerario where
	autorizacao.contrato_codigo = contrato.codigo and contrato_itinerario.veiculo_placa = autorizacao.veiculo_placa and contrato_itinerario.contrato_codigo = autorizacao.contrato_codigo 
	and data_fim >= current_date and autorizacao.renovacao = false and contrato_itinerario.veiculo_placa = _placa
	order by data_fim desc;
	
	loop
		fetch c into r;
		exit when not found;

		if (select veiculo_placa from fretamento.contrato_itinerario where veiculo_placa = _placa and contrato_itinerario.contrato_codigo = r.codigo) = null then
			continue;
		end if;
		
		insert into t values(_placa, seg, vis, r.codigo, r.data_fim, tax, emp, crlv_);
	end loop;


	return query select * from t;


end;
$$;


ALTER FUNCTION fretamento.consulta_placa_site2(_placa text) OWNER TO metroplan;

--
-- Name: conta_a_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_a_vencido(regiao text, data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
auts integer;
begin

	total := 0;
	auts := 0;

	open c for select distinct placa from geral.veiculo where data_inclusao_fretamento is not null and data_exclusao_fretamento is null and fretamento.pertence(placa, regiao) = true;
	loop
		fetch c into r;
		exit when not found;


		contrato := fretamento.pega_contrato(r.placa);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < data then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, contrato) < data then
			auts := auts + 1;
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato) is null or fretamento.veiculo_validade_contrato(contrato) < data then
			i:= i + 1;
		end if;

		if i = 4 then
			auts := auts - 1; --era lixo
		end if;
	
	end loop;

	return auts;

end;
$$;


ALTER FUNCTION fretamento.conta_a_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_aut(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_aut(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct veiculo_placa)::integer from fretamento.autorizacao, geral.empresa, geral.veiculo
where autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj
and (data_inicio + interval '1 year') >= data
and veiculo.data_exclusao_fretamento is null
and regiao_codigo = $1 and renovacao = false
and fretamento.pertence(placa, regiao) = true


$_$;


ALTER FUNCTION fretamento.conta_aut(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_aut_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_aut_vencido(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct autorizacao_codigo)::integer from fretamento.raiz
where
-- autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj and 
data_exclusao_fretamento is null
and regiao_codigo = $1
and (validade_autorizacao) < data
and (
(validade_seguro >= data
			or validade_contrato >= data
			or validade_laudo >= data)
)

and fretamento.pertence(placa, regiao) = true

$_$;


ALTER FUNCTION fretamento.conta_aut_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_c_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_c_vencido(regiao text, data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
cons integer;
begin

	total := 0;
	cons := 0;

	open c for select distinct placa from geral.veiculo where data_inclusao_fretamento is not null and data_exclusao_fretamento is null and fretamento.pertence(placa, regiao) = true;
	loop
		fetch c into r;
		exit when not found;


		contrato := fretamento.pega_contrato(r.placa);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < data then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, contrato) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato) is null or fretamento.veiculo_validade_contrato(contrato) < data then
			cons := cons + 1;
			i:= i + 1;
		end if;

		if i = 4 then
			cons := cons - 1; --era lixo
		end if;
	
	end loop;

	return cons;

end;
$$;


ALTER FUNCTION fretamento.conta_c_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_con_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_con_vencido(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz
where
-- autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj and 
data_exclusao_fretamento is null
and regiao_codigo = $1
and (validade_contrato) < data
and (
(validade_seguro >= data
			or validade_autorizacao >= data
			or validade_laudo >= data)
)
and fretamento.pertence(placa, regiao) = true

$_$;


ALTER FUNCTION fretamento.conta_con_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_cons(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_cons(regiao text) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select count(distinct contrato_codigo)::integer
from geral.veiculo, fretamento.contrato, fretamento.autorizacao
where autorizacao.contrato_codigo = contrato.codigo and autorizacao.veiculo_placa = veiculo.placa
and fretamento.contrato_vencido(contrato.codigo, veiculo.placa) = false
and contrato.regiao_codigo = $1

$_$;


ALTER FUNCTION fretamento.conta_cons(regiao text) OWNER TO metroplan;

--
-- Name: conta_cons(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_cons(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select count(distinct codigo)::integer from fretamento.contrato where regiao_codigo = $1 and 
$2 between data_inicio and data_fim

$_$;


ALTER FUNCTION fretamento.conta_cons(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_cons2(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_cons2(data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select count(distinct codigo)::integer from fretamento.contrato where --regiao_codigo = $1 and 
$1 between data_inicio and data_fim

$_$;


ALTER FUNCTION fretamento.conta_cons2(data date) OWNER TO metroplan;

--
-- Name: conta_cons2(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_cons2(servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select count(distinct codigo)::integer from fretamento.contrato where servico_nome = $1 and 
$2 between data_inicio and data_fim

$_$;


ALTER FUNCTION fretamento.conta_cons2(servico text, data date) OWNER TO metroplan;

--
-- Name: conta_cons_servico(text, text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_cons_servico(regiao text, servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select count(distinct codigo)::integer from fretamento.contrato where regiao_codigo = $1 and 
$3 between data_inicio and data_fim and servico_nome = $2


$_$;


ALTER FUNCTION fretamento.conta_cons_servico(regiao text, servico text, data date) OWNER TO metroplan;

--
-- Name: conta_contrato_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_contrato_vencido(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz
where
-- autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj and 
data_exclusao_fretamento is null
and regiao_codigo = $1
and (validade_contrato) < data
and (
(validade_seguro >= data
			or validade_autorizacao >= data
			or validade_laudo >= data)
)
and fretamento.pertence(placa, regiao) = true

$_$;


ALTER FUNCTION fretamento.conta_contrato_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_emp(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_emp(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $$

select count(distinct empresa_cnpj)::integer from fretamento.raiz
where data_exclusao_fretamento is null
and regiao_codigo = regiao and (validade_seguro >= data
			or validade_contrato >= data
			or validade_laudo >= data
			or validade_autorizacao >= data)
$$;


ALTER FUNCTION fretamento.conta_emp(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_empresas(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_empresas(_regiao text, _data date) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
_cnpj text;
begin

	total := 0;


	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(
		_emp text
	)
	ON COMMIT DROP;



	open c for select * from fretamento.historico where regiao = _regiao and data = _data;
	loop
		fetch c into r;
		exit when not found;

		i := 0;
		if r.seguro > _data then
			i:= i + 1;
		end if;

		if r.taxa > _data then
			i:= i + 1;
		end if;

		if r.contrato > _data then
			i:= i + 1;
		end if;

		if r.laudo > _data then
			i:= i + 1;
		end if;
		
		_cnpj = (select cnpj from geral.empresa, geral.veiculo where veiculo.placa = r.placa and veiculo.empresa_cnpj = empresa.cnpj);
		
		if i > 0 then
			total := total + 1;
			insert into t values ( _cnpj );
		end if;
	
	end loop;

	total := (select count(distinct _emp) from t);

	return total;


end;
$$;


ALTER FUNCTION fretamento.conta_empresas(_regiao text, _data date) OWNER TO metroplan;

--
-- Name: conta_empresas2(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_empresas2(_regiao text, _data date) RETURNS integer
    LANGUAGE plpgsql
    AS $$
declare
total integer;
begin

	
	total := (select count(distinct empresa) from fretamento.historico where regiao = _regiao and data = _data);

	return total;


end;
$$;


ALTER FUNCTION fretamento.conta_empresas2(_regiao text, _data date) OWNER TO metroplan;

--
-- Name: conta_emps(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_emps(regiao text) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select count(distinct cnpj)::integer
from geral.empresa, geral.veiculo, fretamento.contrato, fretamento.autorizacao
where veiculo.empresa_cnpj = empresa.cnpj and autorizacao.contrato_codigo = contrato.codigo and autorizacao.veiculo_placa = veiculo.placa
and fretamento.contrato_vencido(contrato.codigo, veiculo.placa) = false and data_exclusao is null
and contrato.regiao_codigo = $1

$_$;


ALTER FUNCTION fretamento.conta_emps(regiao text) OWNER TO metroplan;

--
-- Name: conta_l_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_l_vencido(regiao text, data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
laus integer;
begin

	total := 0;
	laus := 0;

	open c for select distinct placa from geral.veiculo where data_inclusao_fretamento is not null and data_exclusao_fretamento is null and fretamento.pertence(placa, regiao) = true;
	loop
		fetch c into r;
		exit when not found;


		contrato := fretamento.pega_contrato(r.placa);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < data then
			laus := laus + 1;
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, contrato) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato) is null or fretamento.veiculo_validade_contrato(contrato) < data then
			i:= i + 1;
		end if;

		if i = 4 then
			laus := laus - 1; --era lixo
		end if;
	
	end loop;

	return laus;

end;
$$;


ALTER FUNCTION fretamento.conta_l_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_laudo(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_laudo(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.laudo_vistoria, geral.veiculo
--where autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj
where laudo_vistoria.veiculo_placa = veiculo.placa
and data_validade >= data
and veiculo.data_exclusao_fretamento is null
and (renovacao = false or renovacao is null)
and fretamento.pertence_regiao(veiculo.placa) = $1



$_$;


ALTER FUNCTION fretamento.conta_laudo(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_laudo_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_laudo_vencido(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz
where
-- autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj and 
data_exclusao_fretamento is null
and regiao_codigo = $1
and (validade_laudo) < data
and (
(validade_seguro >= data
			or validade_autorizacao >= data
			or validade_contrato >= data)
)

and fretamento.pertence(placa, regiao) = true
$_$;


ALTER FUNCTION fretamento.conta_laudo_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_s_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_s_vencido(regiao text, data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
segs integer;
begin

	total := 0;
	segs := 0;

	open c for select distinct placa from geral.veiculo where data_inclusao_fretamento is not null and data_exclusao_fretamento is null and fretamento.pertence(placa, regiao) = true;
	loop
		fetch c into r;
		exit when not found;


		contrato := fretamento.pega_contrato(r.placa);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < data then
			segs := segs + 1;
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < data then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, contrato) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato) is null or fretamento.veiculo_validade_contrato(contrato) < data then
			i:= i + 1;
		end if;

		if i = 4 then
			segs := segs - 1; --era lixo
		end if;
	
	end loop;

	return segs;

end;
$$;


ALTER FUNCTION fretamento.conta_s_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_seguro(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_seguro(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from geral.veiculo, geral.empresa
where veiculo.empresa_cnpj = empresa.cnpj
and data_vencimento_seguro >= data
and veiculo.data_exclusao_fretamento is null
and fretamento.pertence_regiao(veiculo.placa) = $1



$_$;


ALTER FUNCTION fretamento.conta_seguro(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_seguro_vencido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_seguro_vencido(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz
where
-- autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj and 
data_exclusao_fretamento is null
and regiao_codigo = $1
and (validade_seguro) < data
and (
(validade_contrato >= data
			or validade_autorizacao >= data
			or validade_laudo >= data)
)
and fretamento.pertence(placa, regiao) = true

$_$;


ALTER FUNCTION fretamento.conta_seguro_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: conta_vencimentos_veiculo(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.conta_vencimentos_veiculo(text) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $_$
declare
aut int;
seg int;
con int;
begin


	aut := (select (data_inicio + interval '1 year') > '2015-10-10'::date) from fretamento.autorizacao where renovacao = false and veiculo_placa = $1;
	seg := (select data_vencimento_seguro > '2015-10-10'::date) from geral.veiculo where placa = $1  ;
	con := (select data_vencimento from contrato where codigo = (select contrato_codigo from fretamento.autorizacao where renovacao = false and veiculo_placa = $1));
	

	return aut + seg + con;

	
end;
$_$;


ALTER FUNCTION fretamento.conta_vencimentos_veiculo(text) OWNER TO metroplan;

--
-- Name: contrato_vencido(integer, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.contrato_vencido(contrato integer, placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT
(select contrato.data_fim from fretamento.contrato, fretamento.autorizacao 
		WHERE autorizacao.contrato_codigo = contrato.codigo and contrato.codigo = $1
		AND autorizacao.veiculo_placa = $2 order by contrato.data_fim desc limit 1) < current_date

$_$;


ALTER FUNCTION fretamento.contrato_vencido(contrato integer, placa text) OWNER TO metroplan;

--
-- Name: contratos_vencidos(date, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.contratos_vencidos(ini date, fim date) RETURNS TABLE(placa text, empresa text, contrato_codigo integer, contrato_vencimento date, contratante text, municipio text)
    LANGUAGE plpgsql
    AS $_$
declare
c refcursor;
r record;
begin

return query select distinct veiculo.placa, empresa.nome, contrato.codigo, contrato.data_fim, contratante.nome, municipio_nome_chegada
from geral.veiculo, geral.empresa, fretamento.contrato, fretamento.autorizacao, fretamento.contratante, fretamento.contrato_itinerario
where veiculo.empresa_cnpj = empresa.cnpj and contrato.codigo = autorizacao.contrato_codigo and autorizacao.veiculo_placa = veiculo.placa
and contrato.contratante_codigo = contratante.codigo and contrato_itinerario.contrato_codigo = contrato.codigo and contrato_itinerario.veiculo_placa = veiculo.placa

and contrato.data_fim between $1 and ($2 - interval '1 day')

order by municipio_nome_chegada, veiculo.placa, data_fim;



end
$_$;


ALTER FUNCTION fretamento.contratos_vencidos(ini date, fim date) OWNER TO metroplan;

--
-- Name: documentacao_vencida(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.documentacao_vencida(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT

coalesce((select (max(empresa.data_entrega_documentacao) + interval '1 year')
from geral.empresa, geral.veiculo
where veiculo.placa = $1
and veiculo.empresa_cnpj = empresa.cnpj
group by empresa.nome, veiculo.placa
) < current_date, true)

$_$;


ALTER FUNCTION fretamento.documentacao_vencida(placa text) OWNER TO metroplan;

--
-- Name: dump_total(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.dump_total(regiao text, data date) RETURNS TABLE(_placa text, _contrato_codigo integer, _contrato text, _seguro text, _taxa text, _laudo text)
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
begin


	CREATE  TEMP TABLE if not exists t
	(
		placa text,
		contrato_codigo integer,
		contrato text,
		seguro text,
		taxa text,
		laudo text
	)
	ON COMMIT DROP;


	total := 0;

	open c for select distinct placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento < data) and (data_exclusao_fretamento is null or data_exclusao_fretamento >= data);
	loop
		fetch c into r;
		exit when not found;

		if (fretamento.pertence(r.placa, regiao)) = false then
			continue;
		end if;

		contrato := fretamento.pega_contrato(r.placa, data);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) >= data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) >= data then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) >= data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato) >= data then
			i:= i + 1;
		end if;

		if i > 0 then
			total := total + 1;
			insert into t (placa, seguro, laudo, taxa, contrato, contrato_codigo) values
			(r.placa, fretamento.veiculo_validade_seguro(r.placa)::text, fretamento.veiculo_validade_laudo(r.placa)::text, fretamento.veiculo_validade_autorizacao(r.placa, contrato)::text, fretamento.veiculo_validade_contrato(contrato)::text, contrato);
		end if;
	
	end loop;

	return query select * from t;

end;
$$;


ALTER FUNCTION fretamento.dump_total(regiao text, data date) OWNER TO metroplan;

--
-- Name: emplacamento_ativo(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.emplacamento_ativo(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

select not retorno from fretamento.emplacamento where placa = $1

$_$;


ALTER FUNCTION fretamento.emplacamento_ativo(placa text) OWNER TO metroplan;

--
-- Name: empresa_excluida(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.empresa_excluida(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT
(select data_exclusao from geral.empresa, geral.veiculo
where placa = $1 and empresa.cnpj = veiculo.empresa_cnpj) <= current_date


$_$;


ALTER FUNCTION fretamento.empresa_excluida(placa text) OWNER TO metroplan;

--
-- Name: empresa_por_cnpj(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.empresa_por_cnpj(cnpj text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select nome from geral.empresa where empresa.cnpj = $1
$_$;


ALTER FUNCTION fretamento.empresa_por_cnpj(cnpj text) OWNER TO metroplan;

--
-- Name: idade_media(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.idade_media(data date) RETURNS TABLE(regiao text, frota integer, media_idade double precision)
    LANGUAGE plpgsql
    AS $$
declare
	c refcursor;
	r record;
	soma_idade integer;
	frota integer;
	idade_media float;
	tmp_placa text;
	tmp integer;

begin
	DROP TABLE IF EXISTS ttab;
	CREATE TEMP TABLE ttab 
	(
		reg text,
		idade integer
	)
	ON COMMIT DROP;

	DROP TABLE IF EXISTS tpla;
	CREATE TEMP TABLE tpla 
	(
		pl text
	)
	ON COMMIT DROP;


	soma_idade = 0;
	frota = 0;
	idade_media = 0;

	open c for select distinct regiao_codigo, placa, ano_fabricacao from fretamento.raiz where data_exclusao_fretamento is null and
		(validade_seguro >= data
		or validade_contrato >= data
		or validade_laudo >= data
		or validade_autorizacao >= data);
	loop
		fetch c into r;
		exit when not found;
		tmp_placa := (select pl from tpla where pl = r.placa);
		if tmp_placa is not null then 
			continue;
		end if;
		frota := frota + 1;
		soma_idade := soma_idade + (extract(year from current_date) - r.ano_fabricacao);
		insert into ttab (reg, idade) values (r.regiao_codigo, (extract(year from current_date) - r.ano_fabricacao));
		insert into tpla (pl) values (r.placa);
		
	end loop;
	close c;
	/*open c for select * from ttab;
	loop
		fetch c into r;
		exit when not found;
	end loop;*/
		--tmp :=  (select count(*) from tpla);
		--raise notice 'frota: % soma_idade % ttab % tpla %', frota, soma_idade, tmp, 0;
		--tmp :=  (select count(*) from ttab);
		--raise notice 'frota: % soma_idade % ttab % tpla %', frota, soma_idade, 0, tmp;

		
		--return query select reg, count(*)::integer , avg(idade)::float from ttab group by reg;
		return query select reg, fretamento.total(reg, data),avg(idade)::float from ttab group by reg; 


end;
$$;


ALTER FUNCTION fretamento.idade_media(data date) OWNER TO metroplan;

--
-- Name: idade_media2(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.idade_media2(data date) RETURNS TABLE(regiao text, frota integer, media_idade double precision)
    LANGUAGE sql STABLE
    AS $$


select regiao_codigo as regiao, fretamento.total(regiao_codigo), avg(extract (year from current_date) - ano_fabricacao) from fretamento.raiz_contagem_vencimentos   where data_exclusao_fretamento is null
and (validade_seguro >= current_date
			or validade_contrato >= current_date
			or validade_laudo >= current_date
			or validade_autorizacao >= current_date)
			and placa not in 
(
									--how do I explicit that I wanna compare the inner one with the outer one?
select placa from fretamento.raiz where data_exclusao_fretamento is null and raiz_contagem_vencimentos.regiao_codigo <> raiz.regiao_codigo
and (validade_seguro >= current_date
			or validade_contrato >= current_date
			or validade_laudo >= current_date
			or validade_autorizacao >= current_date)


) group by regiao_codigo


$$;


ALTER FUNCTION fretamento.idade_media2(data date) OWNER TO metroplan;

--
-- Name: idade_media3(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.idade_media3(data date) RETURNS TABLE(regiao text, frota integer, media_idade double precision)
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
total integer;
soma_idade integer;
contrato integer;
i integer;
begin



	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(
		p text,
		r text,
		i integer
	)
	ON COMMIT DROP;

	total := 0;
	soma_idade := 0;
																			--;--and fretamento.pertence(placa, regiao) = true;
	open c for select distinct placa, ano_fabricacao, regiao_codigo from geral.veiculo, geral.empresa 
	where veiculo.empresa_cnpj = empresa.cnpj and data_inclusao_fretamento is not null and data_inclusao_fretamento < data and data_exclusao_fretamento is null and data_exclusao is null
	and regiao_codigo is not null and regiao_codigo <> 'AUNE';


	loop
		fetch c into r;
		exit when not found;


		contrato := fretamento.pega_contrato(r.placa, data);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < data then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, contrato) < data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato, data) is null or fretamento.veiculo_validade_contrato(contrato, data) < data then
			i:= i + 1;
		end if;

		if i < 4 then
			insert into t (p, r, i) values (r.placa, r.regiao_codigo, (extract(year from current_date) - r.ano_fabricacao));
		end if;

	end loop;

		return query select t.r, fretamento.total_rapido2(t.r, data), avg(t.i)::float from t group by t.r;



	
end;
$$;


ALTER FUNCTION fretamento.idade_media3(data date) OWNER TO metroplan;

--
-- Name: indice_irreg5(text, date, integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.indice_irreg5(pregiao text, data date, code integer) RETURNS TABLE(indice double precision, iaut double precision, icont double precision, ilaudo double precision, iseguro double precision, total integer, irreg integer)
    LANGUAGE plpgsql
    AS $$
declare

total integer;
pendentes integer;
indice float;
idx_aut float;
idx_cont float;
idx_laudo float;
idx_seguro float;
c refcursor;
r record;
aut integer;
cont integer;
laudo integer;
seguro integer;
txt text;
debug integer;
baut boolean;
blau boolean;
bcon boolean;
bseg boolean;
totalzinho integer;
begin


	--DROP TABLE IF EXISTS t;
	CREATE  TEMP TABLE if not exists t
	(
		pl text,
		re text,
		taut boolean,
		tlau boolean,
		tcon boolean,
		tseg boolean,
		tiaut integer,
		tilau integer,
		ticon integer,
		tiseg integer
	)
	ON COMMIT DROP;

		total := 0;
		pendentes := 0;

		debug := 0;
		--total := fretamento.total(pregiao);
		--pendentes := fretamento.pendentes(pregiao);
		aut := 0;
		cont := 0;
		laudo := 0;
		seguro := 0;
		open c for select * from fretamento.raiz_contagem_vencimentos where regiao_codigo = pregiao and data_exclusao_fretamento is null and (validade_seguro >= data
			or validade_contrato >= data
			or validade_laudo >= data
			or validade_autorizacao >= data);


		loop
			fetch c into r;	
			exit when not found;


			if (fretamento.pertence(r.placa, pregiao)) = false then
				continue;
			end if;

			baut := false;
			blau := false;
			bcon := false;
			bseg := false;
			
			
			if r.validade_autorizacao < data then
				aut := aut + 1;
				baut := true;
			end if;
			if r.validade_contrato < data then
				cont := cont + 1;
				bcon := true;
			end if;
			if r.validade_laudo < data then
				laudo := laudo + 1;
				blau := true;
			end if;
			if r.validade_seguro < data then
				seguro := seguro + 1;
				bseg := true;
			end if;

			if (baut or bcon or blau or bseg) = false then
				pendentes := pendentes + 1;
			end if;

			insert into t(pl, taut, tlau, tcon, tseg, tiaut, tilau, ticon, tiseg) values(r.placa, baut, blau, bcon, bseg, aut, laudo, cont, seguro);
			--raise notice 'olha % % % %', aut, cont, laudo, seguro;

		end loop;
		close c;
		--aut := 0;
		--cont := 0;
		---laudo := 0;
		--seguro := 0;

		--aut := (select sum(tiaut) from t);
		--laudo := (select sum(tilau) from t);
		--cont := (select sum(ticon) from t);
		--seguro := (select sum(tiseg) from t);


		--aut := fretamento.qnt_autorizacoes(pregiao, data);
		--cont := fretamento.qnt_contratos(pregiao, data);
		--laudo = fretamento.qnt_laudos(pregiao, data);
		--seguro = fretamento.qnt_seguros(pregiao, data);
		pendentes := fretamento.pendentes(pregiao);

		aut := fretamento.conta_aut_vencido(pregiao, data);
		cont := fretamento.conta_contrato_vencido(pregiao, data);
		laudo  := fretamento.conta_laudo_vencido(pregiao, data);
		seguro := fretamento.conta_seguro_vencido(pregiao, data);
		



		/*indice := (pendentes::float / total::float)::float;
		idx_aut := (aut::float / pendentes::float)::float;
		idx_cont := (cont::float / pendentes::float)::float;
		idx_laudo := (laudo::float / pendentes::float)::float;
		idx_seguro := (seguro::float / pendentes::float)::float;*/

		pendentes := fretamento.pendentes(pregiao);
		total := fretamento.total(pregiao);
		raise notice 'tot % pend %', total, pendentes;
		indice := (pendentes::float / total::float)::float;
		totalzinho := aut + cont + laudo + seguro;

		idx_aut := (aut::float / totalzinho::float)::float;
		idx_cont := (cont::float / totalzinho::float)::float;
		idx_laudo := (laudo::float / totalzinho::float)::float;
		idx_seguro := (seguro::float / totalzinho::float)::float;
		

		return query select indice::float, idx_aut::float, idx_cont::float, idx_laudo::float, idx_seguro::float, total, pendentes;


end;
$$;


ALTER FUNCTION fretamento.indice_irreg5(pregiao text, data date, code integer) OWNER TO metroplan;

--
-- Name: indice_irreg6(text, date, integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.indice_irreg6(pregiao text, data date, code integer) RETURNS TABLE(indice double precision, iaut double precision, icont double precision, ilaudo double precision, iseguro double precision, total integer, irreg integer)
    LANGUAGE plpgsql
    AS $$
declare

total integer;
pendentes integer;
indice float;
idx_aut float;
idx_cont float;
idx_laudo float;
idx_seguro float;
c refcursor;
r record;
aut integer;
cont integer;
laudo integer;
seguro integer;
txt text;
debug integer;
baut boolean;
blau boolean;
bcon boolean;
bseg boolean;
totalzinho integer;
ts timestamp;
begin


	--DROP TABLE IF EXISTS t;
	CREATE  TEMP TABLE if not exists t
	(
		pl text,
		re text,
		taut boolean,
		tlau boolean,
		tcon boolean,
		tseg boolean,
		tiaut integer,
		tilau integer,
		ticon integer,
		tiseg integer
	)
	ON COMMIT DROP;

		total := 0;
		pendentes := 0;
		debug := 0;
		aut := 0;
		cont := 0;
		laudo := 0;
		seguro := 0;

		ts := clock_timestamp();
		raise notice '**********************';
		aut := fretamento.conta_a_vencido(pregiao, data);
		cont := fretamento.conta_c_vencido(pregiao, data);
		laudo  := fretamento.conta_l_vencido(pregiao, data);
		seguro := fretamento.conta_s_vencido(pregiao, data);
		raise notice '********************** os 2 %', (clock_timestamp() - ts);
		/*indice := (pendentes::float / total::float)::float;
		idx_aut := (aut::float / pendentes::float)::float;
		idx_cont := (cont::float / pendentes::float)::float;
		idx_laudo := (laudo::float / pendentes::float)::float;
		idx_seguro := (seguro::float / pendentes::float)::float;*/

		pendentes := fretamento.pend_rapido(pregiao, data);
		total := fretamento.total_rapido2(pregiao, data);
		
		indice := (pendentes::float / total::float)::float;
		totalzinho := aut + cont + laudo + seguro;

		--botar numeros no lugar dos percentuais pra mostrar alex
		--idx_aut := aut;-- (aut::float / totalzinho::float)::float;
		--idx_cont := cont;--(cont::float / totalzinho::float)::float;
		--idx_laudo := laudo;--(laudo::float / totalzinho::float)::float;
		--idx_seguro := seguro;--(seguro::float / totalzinho::float)::float;
		

		idx_aut := (aut::float / totalzinho::float)::float;
		idx_cont := (cont::float / totalzinho::float)::float;
		idx_laudo := (laudo::float / totalzinho::float)::float;
		idx_seguro := (seguro::float / totalzinho::float)::float;



		return query select indice::float, idx_aut::float, idx_cont::float, idx_laudo::float, idx_seguro::float, total, pendentes;


end;
$$;


ALTER FUNCTION fretamento.indice_irreg6(pregiao text, data date, code integer) OWNER TO metroplan;

--
-- Name: laudo_vencido(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.laudo_vencido(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT

(select laudo_vistoria.data_validade from fretamento.laudo_vistoria
		WHERE laudo_vistoria.veiculo_placa = $1 and renovacao = false order by laudo_vistoria.data_validade desc limit 1) < current_date

$_$;


ALTER FUNCTION fretamento.laudo_vencido(placa text) OWNER TO metroplan;

--
-- Name: lugares(text, integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.lugares(placa text, contrato integer) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

--BUGADO E RETORNA ZERO

/*select numero_lugares from fretamento.contrato, fretamento.autorizacao, fretamento.contrato_itinerario
where contrato.codigo = $2 and placa = $1 and contrato.codigo = autorizacao.contrato_codigo
and autorizacao.veiculo_placa = $1 and contrato_itinerario.veiculo_placa = $1
and contrato_itinerario.contrato_codigo = $2*/


select coalesce(numero_lugares, 0) from fretamento.contrato_itinerario
where contrato_codigo = $2 and veiculo_placa = $1



$_$;


ALTER FUNCTION fretamento.lugares(placa text, contrato integer) OWNER TO metroplan;

--
-- Name: lugares_contrato(integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.lugares_contrato(contrato integer) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select sum(numero_lugares)::int as lugares from geral.veiculo where placa in
                (select veiculo_placa from fretamento.contrato_itinerario where contrato_itinerario.contrato_codigo = $1)


$_$;


ALTER FUNCTION fretamento.lugares_contrato(contrato integer) OWNER TO metroplan;

--
-- Name: media_fabricacao_regiao(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.media_fabricacao_regiao(placa text) RETURNS double precision
    LANGUAGE sql STABLE
    AS $_$

select avg(extract(year from current_date) - ano_fabricacao) as idade_media
from fretamento.raiz_contagem_vencimentos
where (validade_seguro >= current_date
or validade_contrato >= current_date
or validade_laudo >= current_date
or validade_autorizacao >= current_date)
and regiao_codigo = $1
group by regiao_codigo


$_$;


ALTER FUNCTION fretamento.media_fabricacao_regiao(placa text) OWNER TO metroplan;

--
-- Name: modelo(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.modelo(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select modelo from geral.veiculo where veiculo.placa = $1;
$_$;


ALTER FUNCTION fretamento.modelo(placa text) OWNER TO metroplan;

--
-- Name: municipios_metroplan(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.municipios_metroplan() RETURNS TABLE(municipio text)
    LANGUAGE sql STABLE
    AS $$

select nome from geral.municipio where regiao_codigo is not null and (nome <> 'RMPA' and nome <> 'RMSG' and nome <> 'AUNE' and nome <> 'AUSUL' and nome <> 'AULINOR' and nome <> 'REGIÃO METROPOLITANA DA SERRA GAÚCHA') order by nome;

$$;


ALTER FUNCTION fretamento.municipios_metroplan() OWNER TO metroplan;

--
-- Name: nome_empresa_por_placa(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.nome_empresa_por_placa(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select nome as nome_empresa from geral.empresa, geral.veiculo where veiculo.placa = $1 and veiculo.empresa_cnpj = empresa.cnpj
$_$;


ALTER FUNCTION fretamento.nome_empresa_por_placa(placa text) OWNER TO metroplan;

--
-- Name: passageiros(integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.passageiros(contrato integer) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select numero_passageiros from fretamento.contrato where contrato.codigo = $1


$_$;


ALTER FUNCTION fretamento.passageiros(contrato integer) OWNER TO metroplan;

--
-- Name: pega_contrato(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_contrato(placa text) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select autorizacao.contrato_codigo from fretamento.autorizacao, fretamento.contrato, fretamento.contrato_itinerario
		WHERE autorizacao.veiculo_placa = $1 
		and renovacao = false
		and autorizacao.contrato_codigo = contrato.codigo
		and contrato_itinerario.veiculo_placa = $1 and contrato_itinerario.contrato_codigo = contrato.codigo
		order by contrato.data_fim desc limit 1

$_$;


ALTER FUNCTION fretamento.pega_contrato(placa text) OWNER TO metroplan;

--
-- Name: pega_contrato(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_contrato(placa text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select autorizacao.contrato_codigo from fretamento.autorizacao, fretamento.contrato, fretamento.contrato_itinerario, geral.veiculo
		WHERE autorizacao.veiculo_placa = $1 
		--and renovacao = false
		and veiculo.data_inclusao_fretamento <= data
		and (veiculo.data_exclusao_fretamento is null or veiculo.data_exclusao_fretamento > data)
		and autorizacao.contrato_codigo = contrato.codigo
		and contrato_itinerario.veiculo_placa = $1 and contrato_itinerario.contrato_codigo = contrato.codigo
		and veiculo.placa = $1
		and data between contrato.data_inicio and data_fim
		order by contrato.data_fim desc limit 1

$_$;


ALTER FUNCTION fretamento.pega_contrato(placa text, data date) OWNER TO metroplan;

--
-- Name: pega_contrato_forca(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_contrato_forca(placa text) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

--modificado pega_contrato() pra pegar o contrato mesmo sem autoricacao. a ser utilizado no relatorio total do fret sem deixar campos em branco
--possivelmente avaliar melhor isso no futuro

select contrato.codigo from fretamento.contrato, fretamento.contrato_itinerario
		WHERE contrato_itinerario.veiculo_placa = $1 
		and contrato_itinerario.contrato_codigo = contrato.codigo
		order by contrato.data_fim desc limit 1

$_$;


ALTER FUNCTION fretamento.pega_contrato_forca(placa text) OWNER TO metroplan;

--
-- Name: pega_contratos_multiplos(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_contratos_multiplos(placa text) RETURNS integer[]
    LANGUAGE sql STABLE
    AS $_$
--RETORNA UM ARRAY
select array_agg(distinct autorizacao.contrato_codigo) from fretamento.autorizacao, fretamento.contrato, fretamento.contrato_itinerario
		WHERE autorizacao.veiculo_placa = $1
		and renovacao = false
		and autorizacao.contrato_codigo = contrato.codigo
		and contrato_itinerario.veiculo_placa = $1 and contrato_itinerario.contrato_codigo = contrato.codigo
		

$_$;


ALTER FUNCTION fretamento.pega_contratos_multiplos(placa text) OWNER TO metroplan;

--
-- Name: pega_empresa(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_empresa(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select cnpj from geral.empresa, geral.veiculo where veiculo.placa = $1 and veiculo.empresa_cnpj = empresa.cnpj
$_$;


ALTER FUNCTION fretamento.pega_empresa(placa text) OWNER TO metroplan;

--
-- Name: pega_empresa_nome(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_empresa_nome(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select nome from geral.empresa, geral.veiculo where veiculo.placa = $1 and veiculo.empresa_cnpj = empresa.cnpj
$_$;


ALTER FUNCTION fretamento.pega_empresa_nome(placa text) OWNER TO metroplan;

--
-- Name: pega_regiao(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_regiao(placa text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
declare
regiao text;
begin

regiao := (select regiao_codigo from fretamento.contrato, fretamento.autorizacao, fretamento.contrato_itinerario
					where autorizacao.contrato_codigo = contrato.codigo
					and autorizacao.veiculo_placa = placa
					and contrato_itinerario.veiculo_placa = placa and contrato_itinerario.contrato_codigo = contrato.codigo
					group by regiao_codigo
					order by count(*) desc, regiao_codigo
					limit 1);
if regiao is null then
	regiao := (select regiao_codigo from geral.veiculo, geral.empresa where veiculo.empresa_cnpj = empresa.cnpj and veiculo.placa = $1);
end if;

return regiao;


end;
$_$;


ALTER FUNCTION fretamento.pega_regiao(placa text) OWNER TO metroplan;

--
-- Name: pega_subcontratado(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_subcontratado(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$

SELECT nome from geral.empresa, geral.veiculo, fretamento.autorizacao, fretamento.contrato
where empresa.cnpj = autorizacao.empresa_cnpj_sublocacao
and autorizacao.veiculo_placa = veiculo.placa
and contrato.empresa_cnpj = empresa.cnpj
and renovacao = false
and data_fim >= current_date
and placa = $1

$_$;


ALTER FUNCTION fretamento.pega_subcontratado(placa text) OWNER TO metroplan;

--
-- Name: pega_subcontratado2(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_subcontratado2(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$

SELECT nome from geral.empresa, geral.veiculo, fretamento.autorizacao
where placa = $1
and empresa.cnpj = autorizacao.empresa_cnpj_sublocacao
and autorizacao.veiculo_placa = veiculo.placa
and renovacao = false
--and data_fim >= current_date

$_$;


ALTER FUNCTION fretamento.pega_subcontratado2(placa text) OWNER TO metroplan;

--
-- Name: pega_tipo(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pega_tipo(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select fretamento_veiculo_tipo_nome from geral.veiculo where veiculo.placa = $1;
$_$;


ALTER FUNCTION fretamento.pega_tipo(placa text) OWNER TO metroplan;

--
-- Name: pend_rap2(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pend_rap2(regiao text, data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
begin

	total := 0;

	open c for select distinct placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento < data) and (data_exclusao_fretamento is null or data_exclusao_fretamento > data);
	loop
		fetch c into r;
		exit when not found;

		if (fretamento.pertence(r.placa, regiao)) = false then
			continue;
		end if;

		contrato := fretamento.pega_contrato(r.placa, data);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) >= data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa, data) >= data then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) >= data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato, data) >= data then
			i:= i + 1;
		end if;

		if i > 0 and i < 4 then
			total := total + 1;
		end if;
	
	end loop;

	return total;

end;
$$;


ALTER FUNCTION fretamento.pend_rap2(regiao text, data date) OWNER TO metroplan;

--
-- Name: pend_rapido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pend_rapido(_regiao text, _data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
begin

	total := 0;

	open c for select * from fretamento.historico where regiao = _regiao and data = _data;
	loop
		fetch c into r;
		exit when not found;
		i := 0;

		if r.seguro > _data then
			i:= i + 1;
		end if;

		if r.taxa > _data then
			i:= i + 1;
		end if;

		if r.contrato > _data then
			--i:= i + 1;
		end if;

		if r.laudo > _data then
			i:= i + 1;
		end if;

		if i > 0 and i < 3 then
			total := total + 1;
		end if;
	
	end loop;

	return total;

end;
$$;


ALTER FUNCTION fretamento.pend_rapido(_regiao text, _data date) OWNER TO metroplan;

--
-- Name: pendentes(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pendentes() RETURNS integer
    LANGUAGE sql STABLE
    AS $$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null
and (validade_seguro >= current_date
			or validade_contrato >= current_date
			or validade_laudo >= current_date
			or validade_autorizacao >= current_date)
			and placa not in (
			select distinct placa from fretamento.raiz where data_exclusao_fretamento is null
				and (validade_seguro >= current_date
				and validade_contrato >= current_date
				and validade_laudo >= current_date
				and validade_autorizacao >= current_date)
)



$$;


ALTER FUNCTION fretamento.pendentes() OWNER TO metroplan;

--
-- Name: pendentes(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pendentes(data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null
and (validade_seguro >= data
			or validade_contrato >= data
			or validade_laudo >= data
			or validade_autorizacao >= data)
			and placa not in (
			select distinct placa from fretamento.raiz where data_exclusao_fretamento is null
				and (validade_seguro >= data
				and validade_contrato >= data
				and validade_laudo >= data
				and validade_autorizacao >= data)
)



$$;


ALTER FUNCTION fretamento.pendentes(data date) OWNER TO metroplan;

--
-- Name: pendentes(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pendentes(regiao text) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null and regiao_codigo = $1
and (validade_seguro >= current_date
			or validade_contrato >= current_date
			or validade_laudo >= current_date
			or validade_autorizacao >= current_date)
			and placa not in (
			select distinct placa from fretamento.raiz where data_exclusao_fretamento is null
				and (validade_seguro >= current_date
				and validade_contrato >= current_date
				and validade_laudo >= current_date
				and validade_autorizacao >= current_date)
)
--and (fretamento.pertence(regiao, placa) = true)


$_$;


ALTER FUNCTION fretamento.pendentes(regiao text) OWNER TO metroplan;

--
-- Name: pendentes(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pendentes(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null and regiao_codigo = $1
and (validade_seguro >= data
			or validade_contrato >= data
			or validade_laudo >= data
			or validade_autorizacao >= data)
			and placa not in (
			select distinct placa from fretamento.raiz where data_exclusao_fretamento is null
				and (validade_seguro >= data
				and validade_contrato >= data
				and validade_laudo >= data
				and validade_autorizacao >= data)
)
--and (fretamento.pertence(regiao, placa) = true)


$_$;


ALTER FUNCTION fretamento.pendentes(regiao text, data date) OWNER TO metroplan;

--
-- Name: pertence(text, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.pertence(placa text, regiao text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
declare

reg text;

begin

reg := (select regiao_codigo from fretamento.contrato, fretamento.autorizacao, fretamento.contrato_itinerario
					where autorizacao.contrato_codigo = contrato.codigo
					and autorizacao.veiculo_placa = placa
					and contrato_itinerario.veiculo_placa = placa and contrato_itinerario.contrato_codigo = contrato.codigo
					group by regiao_codigo
					order by count(*) desc, regiao_codigo
					limit 1);

if reg is null then return false; end if;
return (reg = regiao);

end;
$$;


ALTER FUNCTION fretamento.pertence(placa text, regiao text) OWNER TO metroplan;

--
-- Name: placas_pend(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.placas_pend(_data date) RETURNS TABLE(pla text)
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
begin


CREATE  TEMP TABLE if not exists t
	(
		pl text

	)
	ON COMMIT DROP;

	

	total := 0;

	open c for select * from fretamento.historico where data = _data and (regiao = 'RMPA' or regiao = 'RMSG' or regiao = 'AUSUL' or regiao = 'AULINOR');
	loop
		fetch c into r;
		exit when not found;
		i := 0;

		if r.seguro > _data then
			i:= i + 1;
		end if;

		if r.taxa > _data then
			i:= i + 1;
		end if;

		if r.contrato > _data then
			i:= i + 1;
		end if;

		if r.laudo > _data then
			i:= i + 1;
		end if;



		if i > 0 and i < 4 then
			insert into t values(r.placa);
		end if;
	
	end loop;

	return query select pl from t;

end;
$$;


ALTER FUNCTION fretamento.placas_pend(_data date) OWNER TO metroplan;

--
-- Name: placas_pend_ignora_contrato(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.placas_pend_ignora_contrato(_data date) RETURNS TABLE(pla text)
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
begin


CREATE  TEMP TABLE if not exists t
	(
		pl text

	)
	ON COMMIT DROP;

	

	total := 0;

	open c for select * from fretamento.historico where data = _data and (regiao = 'RMPA' or regiao = 'RMSG' or regiao = 'AUSUL' or regiao = 'AULINOR');
	loop
		fetch c into r;
		exit when not found;
		i := 0;

		if r.seguro < _data and r.seguro is not null then
			i:= i + 1;
		end if;

		if r.taxa < _data and r.taxa is not null then
			i:= i + 1;
		end if;

		if r.laudo < _data and r.laudo is not null then
			i:= i + 1;
		end if;

		if i > 0 and i < 3 then
			insert into t values(r.placa);
		end if;

		raise notice USING MESSAGE = r.placa || ' ' || i::text;
	
	end loop;

	return query select pl from t;

end;
$$;


ALTER FUNCTION fretamento.placas_pend_ignora_contrato(_data date) OWNER TO metroplan;

--
-- Name: processo_encerrado(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.processo_encerrado(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT
(select fretamento_processo.data_encerramento from fretamento.fretamento_processo, geral.empresa, geral.veiculo
		WHERE fretamento_processo.codigo = empresa.processo and veiculo.placa = $1 and veiculo.empresa_cnpj = empresa.cnpj
		) < current_date



$_$;


ALTER FUNCTION fretamento.processo_encerrado(placa text) OWNER TO metroplan;

--
-- Name: proxima_autorizacao(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.proxima_autorizacao() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $_$
declare
num text;
counter integer;
teste text;
resultado text;
max_size int;
begin

	--LOCK IT DAMNIT!!
	
	--num := (select ((substring(11500+(codigo from 1 for length(codigo)-2))::int+1))::text from fretamento.autorizacao 
	max_size = 6; 
	num := (select ((substring(codigo from 1 for max_size)::int+1))::text from fretamento.autorizacao 
		where codigo is not null and length(codigo) = max_size+2 and
		substring(codigo from '..$') = to_char(now(), 'yy')
		order by substring(codigo from 1 for max_size) desc
		limit 1);

	if num is null then
		num := '000001';
	end if;


	if num = '1000000' then --codigo era 999999
		counter := 1;
		<<encontra_slot>>
		loop
			teste := lpad(counter::text, max_size - 2, '0');
			resultado := (select ((substring(codigo from 1 for max_size))::int+1)::text from fretamento.autorizacao 
				     where codigo is not null and length(codigo) = max_size and
				     substring(codigo from '..$') = to_char(now(), 'yy')
				     and teste = substring(codigo from 1 for max_size-2)
				     order by substring(codigo from 1 for max_size) desc
				     limit 1);
			if resultado is null then
				num := teste;
				exit encontra_slot;
			end if;
			counter := counter + 1;
			exit when counter = 999999;
		end loop encontra_slot;
	end if;
	
	num := num || to_char(now(), 'yy');

	if length(num) < max_size+2 then
		num := lpad(num, 8, '0');
	end if;

	return num;

end;
$_$;


ALTER FUNCTION fretamento.proxima_autorizacao() OWNER TO metroplan;

--
-- Name: proxima_hlp(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.proxima_hlp() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
declare
num text;
counter integer;
teste text;
resultado text;
begin
	num := (select sequencial from fretamento.hlp 
		where ano = date_part('year', now())
		order by sequencial desc
		limit 1);

	if num is null then
		num := '0001';
		return num;
	end if;

	num := ((num::int)+1)::text;

	if length(num) < 4 then
		num := lpad(num, 4, '0');
	end if;
	
	return num;

end;
$$;


ALTER FUNCTION fretamento.proxima_hlp() OWNER TO metroplan;

--
-- Name: regiao_por_municipio(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.regiao_por_municipio(municipio text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$

select regiao_codigo from geral.municipio where nome = $1

$_$;


ALTER FUNCTION fretamento.regiao_por_municipio(municipio text) OWNER TO metroplan;

--
-- Name: regiao_veiculo(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.regiao_veiculo(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $$

select codigo as regiao_codigo 

from geral.veiculo, geral.regiao, geral.empresa 

where veiculo.empresa_cnpj = empresa.cnpj and empresa.regiao_codigo = regiao.codigo


$$;


ALTER FUNCTION fretamento.regiao_veiculo(placa text) OWNER TO metroplan;

--
-- Name: registra_historico(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.registra_historico() RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
_contrato_codigo integer;
_taxa date;
_laudo date;
_seguro date;
_contrato date;
_regiao text;
_empresa text;
_servico text;
_passageiros integer;
_lugares integer;
total integer;
bom integer;
begin

	total := 0;

	if (select placa from fretamento.historico where data = current_date limit 1) is not null then
		delete from fretamento.historico where data = current_date;
	end if;

	open c for select distinct placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento <= current_date) and (data_exclusao_fretamento is null or data_exclusao_fretamento > current_date);
	loop
		fetch c into r;
		exit when not found;

		_contrato_codigo := fretamento.pega_contrato(r.placa, current_date);

		_seguro := fretamento.veiculo_validade_seguro(r.placa);

		_laudo := fretamento.veiculo_validade_laudo(r.placa, current_date);

		_taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);

		_contrato := fretamento.veiculo_validade_contrato(_contrato_codigo, current_date);
	
		_regiao := fretamento.pega_regiao(r.placa);

		_servico := fretamento.servico(_contrato_codigo);

		_passageiros := fretamento.passageiros(_contrato_codigo);

		_lugares := fretamento.lugares(r.placa, _contrato_codigo);

		bom := 0;
		
		if _seguro is not null and _seguro > current_date then
			bom := bom + 1;
		end if;
		if _laudo is not null and _laudo > current_date then
			bom := bom + 1;
		end if;
		if _taxa is not null and _taxa > current_date then
			bom := bom + 1;
		end if;
		--if _contrato is not null and _contrato > current_date then
			--bom := bom + 1;
		--end if;
		
		if bom > 0 then
			_empresa := (fretamento.pega_empresa(r.placa));
			insert into fretamento.historico (placa, regiao, contrato, seguro, taxa, laudo ,data, empresa, servico, passageiros, lugares)
			values(r.placa, _regiao, _contrato, _seguro, _taxa, _laudo, current_date, _empresa, _servico, _passageiros, _lugares);
			total := total + 1;
		end if;
	end loop;


	return total;
	
end;
$$;


ALTER FUNCTION fretamento.registra_historico() OWNER TO metroplan;

--
-- Name: registra_historico_data(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.registra_historico_data(dt date) RETURNS integer
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
_contrato_codigo integer;
_taxa date;
_laudo date;
_seguro date;
_contrato date;
_regiao text;
_empresa text;
_servico text;
_passageiros integer;
_lugares integer;
total integer;
bom integer;
begin

	total := 0;

	if (select placa from fretamento.historico where data = dt limit 1) is not null then
		delete from fretamento.historico where data = dt;
	end if;

	open c for select distinct placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento <= current_date) and (data_exclusao_fretamento is null or data_exclusao_fretamento > dt);
	loop
		fetch c into r;
		exit when not found;

		_contrato_codigo := fretamento.pega_contrato(r.placa, dt);

		_seguro := fretamento.veiculo_validade_seguro(r.placa);

		_laudo := fretamento.veiculo_validade_laudo(r.placa, dt);

		_taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);

		_contrato := fretamento.veiculo_validade_contrato(_contrato_codigo, dt);
	
		_regiao := fretamento.pega_regiao(r.placa);

		_servico := fretamento.servico(_contrato_codigo);

		_passageiros := fretamento.passageiros(_contrato_codigo);

		_lugares := fretamento.lugares(r.placa, _contrato_codigo);

		bom := 0;
		
		if _seguro is not null and _seguro > dt then
			bom := bom + 1;
		end if;
		if _laudo is not null and _laudo > dt then
			bom := bom + 1;
		end if;
		if _taxa is not null and _taxa > dt then
			bom := bom + 1;
		end if;
		--if _contrato is not null and _contrato > dt then
			--bom := bom + 1;
		--end if;
		
		if bom > 0 then
			_empresa := (fretamento.pega_empresa(r.placa));
			insert into fretamento.historico (placa, regiao, contrato, seguro, taxa, laudo ,data, empresa, servico, passageiros, lugares)
			values(r.placa, _regiao, _contrato, _seguro, _taxa, _laudo, dt, _empresa, _servico, _passageiros, _lugares);
			total := total + 1;
		end if;
	end loop;


	return total;
	
end;
$$;


ALTER FUNCTION fretamento.registra_historico_data(dt date) OWNER TO metroplan;

--
-- Name: _rel_4ok; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE UNLOGGED TABLE fretamento._rel_4ok (
    placa text NOT NULL,
    regiao text,
    contrato_codigo integer,
    contrato date,
    seguro date,
    taxa date,
    laudo date,
    cnpj text,
    empresa text,
    lugares integer,
    ano_fabricacao integer,
    modelo text,
    tipo text
);


ALTER TABLE fretamento._rel_4ok OWNER TO metroplan;

--
-- Name: TABLE _rel_4ok; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON TABLE fretamento._rel_4ok IS 'unlogged table = maior performance
usada pra facilitar a adaptação do registra_historico(), que daria mais trabalho fazer retornar uma tabela com puro codigo.
idealmente fazer da forma correta no futuro';


--
-- Name: rel_4ok(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.rel_4ok() RETURNS SETOF fretamento._rel_4ok
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
_contrato_codigo integer;
_taxa date;
_laudo date;
_seguro date;
_contrato date;
_regiao text;
_empresa text;
_cnpj text;
_lugares integer;
_ano integer;
_modelo text;
_tipo text;
total integer;
bom integer;
data_corte date;
begin

	total := 0;

	data_corte := current_date  - INTERVAL '2 years';

	delete from fretamento._rel_4ok;
	
	open c for select distinct placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento <= current_date) and (data_exclusao_fretamento is null or data_exclusao_fretamento > current_date);
	loop
		fetch c into r;
		exit when not found;

		_contrato_codigo := fretamento.pega_contrato(r.placa);
		if _contrato_codigo is null then
			RAISE NOTICE '[%]', _contrato_codigo;
			_contrato_codigo := fretamento.pega_contrato_forca(r.placa);
			RAISE NOTICE '[%]', _contrato_codigo;
		end if;

		_seguro := fretamento.veiculo_validade_seguro(r.placa);

		_laudo := fretamento.veiculo_validade_laudo(r.placa);

		_taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);

		_contrato := fretamento.veiculo_validade_contrato(_contrato_codigo);
	
		_regiao := fretamento.pega_regiao(r.placa);

		_lugares := fretamento.lugares_contrato(_contrato_codigo);

		_ano := fretamento.ano_fabricacao(r.placa);

		_modelo := fretamento.modelo(r.placa);

		_tipo := fretamento.tipo(r.placa);


		bom := 0;
		
		if _seguro is not null and _seguro > data_corte then
			bom := bom + 1;
		end if;
		if _laudo is not null and _laudo > data_corte then
			bom := bom + 1;
		end if;
		if _taxa is not null and _taxa > data_corte then
			bom := bom + 1;
		end if;
		if _contrato is not null and _contrato > data_corte then
			bom := bom + 1;
		end if;
		
		if bom = 4 then

			_cnpj := (fretamento.pega_empresa(r.placa));
			_empresa := (fretamento.pega_empresa_nome(r.placa));

			insert into fretamento._rel_4ok (placa, regiao, contrato_codigo, contrato, seguro, taxa, laudo, empresa, cnpj, lugares, ano_fabricacao, modelo, tipo)
			values(r.placa, _regiao, _contrato_codigo, _contrato, _seguro, _taxa, _laudo, _empresa, _cnpj, _lugares, _ano, _modelo, _tipo);
			total := total + 1;
		end if;
	end loop;


	return query select * from fretamento._rel_4ok order by regiao, empresa, placa;
	
end;
$$;


ALTER FUNCTION fretamento.rel_4ok() OWNER TO metroplan;

--
-- Name: rel_autorizacao(text, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.rel_autorizacao(contrato text, placa text) RETURNS TABLE(cnpj text, contratada text, processo text, inscricao_estadual text, data_vencimento_seguro text, contrato_codigo text, contratante text, municipio text, servico_contratado text, autorizacao_codigo text, autorizacao_validade text, laudo_validade text, pagamento_vencimento text, contrato_inicio text, contrato_vencimento text, placa text, empresa_cnpj_sublocacao text, entidade_estudantil text)
    LANGUAGE sql STABLE
    AS $_$

SELECT
distinct on (placa, contrato)
  geral.formata_cnpj(empresa.cnpj) AS cnpj,
  empresa.nome AS contratada,
  geral.formata_processo(autorizacao.processo) AS processo,
  empresa.inscricao_estadual AS inscricao_estadual,
  to_char(veiculo.data_vencimento_seguro, 'DD/MM/YYYY') as data_vencimento_seguro,
  contrato.codigo::text AS contrato_codigo,
  contratante.nome AS contratante,
  contratante.municipio_nome AS municipio,
  contrato.servico_nome AS servico_contratado,
  autorizacao.codigo::text AS autorizacao_codigo,
  
  to_char( (select d from ( select veiculo.data_vencimento_seguro as d
  union select contrato.data_fim as d
  union select laudo_vistoria.data_validade as d
  union select (autorizacao.data_inicio + interval '1 year') as d)
  as d order by d asc limit 1), 'DD/MM/YYYY') as autorizacao_validade,

  to_char(laudo_vistoria.data_validade, 'DD/MM/YYYY') AS laudo_validade,

  to_char(
case when (autorizacao.data_inicio + interval '1 year') < contrato.data_fim
--voltando atras
or true = true then
(autorizacao.data_inicio + interval '1 year') else contrato.data_fim end, 'DD/MM/YYYY') as pagamento_vencimento,
to_char(contrato.data_inicio, 'DD/MM/YYYY') AS contrato_inicio,
  to_char(contrato.data_fim, 'DD/MM/YYYY') AS contrato_vencimento,


  autorizacao.veiculo_placa AS placa,
  empresa_cnpj_sublocacao
,entidade_estudantil
  
FROM
  fretamento.autorizacao,
  fretamento.contratante,
  fretamento.contrato,
  geral.empresa,
  fretamento.laudo_vistoria,
  geral.veiculo
WHERE
  autorizacao.contrato_codigo = contrato.codigo AND
  contratante.codigo = contrato.contratante_codigo AND
  contrato.empresa_cnpj = empresa.cnpj AND
  laudo_vistoria.veiculo_placa = autorizacao.veiculo_placa AND
  veiculo.placa = autorizacao.veiculo_placa AND
  autorizacao.contrato_codigo::text = any(string_to_array($1, ',')) and
  autorizacao.veiculo_placa = any(string_to_array($2, ','))

  --2018-05-02
  and autorizacao.renovacao = false
  and laudo_vistoria.renovacao = false
  
  ORDER BY
  placa, contrato, laudo_vistoria.data_validade DESC, autorizacao.data_inicio DESC;


$_$;


ALTER FUNCTION fretamento.rel_autorizacao(contrato text, placa text) OWNER TO metroplan;

--
-- Name: rel_quant(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.rel_quant(data date) RETURNS TABLE(regiao_codigo text, empresas integer, contratos integer, veiculos_ok integer, veiculos_irregulares integer, total integer)
    LANGUAGE plpgsql
    AS $$
declare
	v integer;
	c refcursor;
	r record;
	soma_idade integer;
	frota integer;
	idade_media float;
	tmp_placa text;
	tmp integer;
	emp text;
	con text;
	pla text;
	numemp integer;
	numcon integer;
	numpla integer;
	numpen integer;
	total integer;
	re integer; --regiao
	umbom integer;
	umruim integer;
	debug integer;
	aut integer;
	cont integer;
	laudo integer;
	seguro integer;
	val integer;
	pregiao text;
	txt text;
begin

	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(
		pl text, --placa
		cn text, --cnpj empersas
		co text,  --contrato
		re text,
		bom integer,
		pend integer,
		validacoes integer
	)
	ON COMMIT DROP;


	open c for select validade_seguro, validade_contrato, validade_laudo, validade_autorizacao, contrato_codigo, empresa_cnpj, raiz.regiao_codigo, placa, raiz.ano_fabricacao from fretamento.raiz where data_exclusao_fretamento is null and
		(validade_seguro >= data
		or validade_contrato >= data
		or validade_laudo >= data
		or validade_autorizacao >= data);

	loop
	
		fetch c into r;
		exit when not found;


		txt := (select contrato.regiao_codigo from fretamento.contrato, fretamento.autorizacao
				where autorizacao.contrato_codigo = contrato.codigo
				and autorizacao.veiculo_placa = r.placa
				group by contrato.regiao_codigo
				order by count(*) desc, contrato.regiao_codigo
				limit 1);

		if txt is not null then
			pregiao := txt;
		else
			pregiao := r.regiao_codigo;
		end if;

		
		val := 0;
		if (r.validade_autorizacao >= data) then
			val = val + 1; 
		end if;
		if (r.validade_contrato >= data) then 
			val = val + 1;
		end if;
		if (r.validade_laudo >= data) then 
			val = val + 1;
		end if;
		if (r.validade_seguro >= data) then
			val = val + 1; 
		end if;

		umbom := 0;
		umruim := 0;
		if val = 4 then
			umbom := 1;
		else
			umruim := 1;
		end if;

		v := (select validacoes from t where pl = r.placa);
		if v is not null then
			if val > v then
				update t set validacoes = val where pl = r.placa;
				if val = 4 then
					update t set bom = 1, pend = 0 where pl = r.placa;
				end if;
			end if;
		else 
			insert into t (pl, cn, co, re, bom, pend, validacoes) values (r.placa, null, null, pregiao, umbom, umruim, val);
			total := total + 1;
		end if;

		emp := (select cn from t where cn = r.empresa_cnpj);
		if emp is null then
			insert into t (pl, cn, co, re, bom, pend) values (null, r.empresa_cnpj, null, pregiao, 0, 0);
			numemp := numemp + 1;
		end if;

		con := (select co from t where co::integer = r.contrato_codigo);
		if con is null then
			insert into t (pl, cn, co, re, bom, pend) values (null, null, r.contrato_codigo, pregiao, 0, 0);
			numcon := numcon + 1;
		end if;

	end loop;
	close c;

	return query select t.re, count(cn)::integer, count(co)::integer, fretamento.total(pregiao)::integer, fretamento.pendentes(pregiao)::integer, (total(pregiao))::integer as total from t group by t.re;


end;
$$;


ALTER FUNCTION fretamento.rel_quant(data date) OWNER TO metroplan;

--
-- Name: rel_quant2(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.rel_quant2(data date) RETURNS TABLE(regiao_codigo text, empresas integer, contratos integer, veiculos_ok integer, veiculos_irregulares integer, total integer)
    LANGUAGE plpgsql
    AS $$
declare
	v integer;
	c refcursor;
	r record;
	soma_idade integer;
	frota integer;
	idade_media float;
	tmp_placa text;
	tmp integer;
	emp text;
	con text;
	pla text;
	numemp integer;
	numcon integer;
	numpla integer;
	numpen integer;
	total integer;
	re integer; --regiao
	umbom integer;
	umruim integer;
	debug integer;
	aut integer;
	cont integer;
	laudo integer;
	seguro integer;
	val integer;

begin

	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(
		pl text, --placa
		cn text, --cnpj empersas
		co text,  --contrato
		re text,
		bom integer,
		pend integer,
		validacoes integer
	)
	ON COMMIT DROP;


	open c for select validade_seguro, validade_contrato, validade_laudo, validade_autorizacao, contrato_codigo, empresa_cnpj, raiz_contagem_vencimentos.regiao_codigo, placa, raiz_contagem_vencimentos.ano_fabricacao from fretamento.raiz_contagem_vencimentos where data_exclusao_fretamento is null and
		(validade_seguro >= data
		or validade_contrato >= data
		or validade_laudo >= data
		or validade_autorizacao >= data);

	loop
	
		fetch c into r;
		exit when not found;

		if (fretamento.pertence_regiao(r.placa) <> r.regiao_codigo) then
			continue;
		end if;

		val := 0;
		if (r.validade_autorizacao >= data) then
			val = val + 1; 
		end if;
		if (r.validade_contrato >= data) then 
			val = val + 1;
		end if;
		if (r.validade_laudo >= data) then 
			val = val + 1;
		end if;
		if (r.validade_seguro >= data) then
			val = val + 1; 
		end if;
		
		umbom := 0;
		umruim := 0;
		if val = 4 then
			umbom := 1;
		else
			umruim := 1;
		end if;

		v := (select validacoes from t where pl = r.placa);
		if v is not null then
			if val > v then
				update t set validacoes = val where pl = r.placa;
				if val = 4 then
					update t set bom = 1, pend = 0 where pl = r.placa;
				end if;
			end if;
		else 
			insert into t (pl, cn, co, re, bom, pend, validacoes) values (r.placa, null, null, r.regiao_codigo, umbom, umruim, val);
			total := total + 1;
		end if;

		emp := (select cn from t where cn = r.empresa_cnpj);
		if emp is null then
			insert into t (pl, cn, co, re, bom, pend) values (null, r.empresa_cnpj, null, r.regiao_codigo, 0, 0);
			numemp := numemp + 1;
		end if;

		con := (select co from t where co::integer = r.contrato_codigo);
		if con is null then
			insert into t (pl, cn, co, re, bom, pend) values (null, null, r.contrato_codigo, r.regiao_codigo, 0, 0);
			numcon := numcon + 1;
		end if;

	end loop;
	close c;

	
	
	---return query select t.re, count(cn)::integer, count(co)::integer, fretamento.bons(t.re), fretamento.pendentes(t.re), total(t.re) as total from t group by t.re;
	   --return query select t.re, count(cn)::integer, count(co)::integer, sum(bom)::integer, sum(pend)::integer, (sum(bom) + sum(pend))::integer as total from t group by t.re;
	   return query select t.re, count(cn)::integer, count(co)::integer, ((fretamento.total(t.re)) - (fretamento.pendentes(t.re))), fretamento.pendentes(t.re), (fretamento.total(t.re))::integer as total from t group by t.re;


end;
$$;


ALTER FUNCTION fretamento.rel_quant2(data date) OWNER TO metroplan;

--
-- Name: rel_quant3(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.rel_quant3(regiao text, data date) RETURNS TABLE(regiao_codigo text, empresas integer, contratos integer, veiculos_ok integer, veiculos_irregulares integer, total integer)
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
pens integer;
begin


total := fretamento.total_rapido2(regiao, data);
pens := fretamento.pend_rapido(regiao, data);


return query select 
regiao, 
fretamento.conta_empresas2(regiao, data), 
fretamento.conta_cons(regiao, data), 
(total) - (pens), 
pens,
total as total;

end;
$$;


ALTER FUNCTION fretamento.rel_quant3(regiao text, data date) OWNER TO metroplan;

--
-- Name: rel_tipo_regiao(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.rel_tipo_regiao() RETURNS TABLE(placa text, regiao text, tipo text)
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
_contrato_codigo integer;
_taxa date;
_laudo date;
_seguro date;
_contrato date;
_regiao text;
_empresa text;
_servico text;
total integer;
bom integer;
begin

	CREATE  TEMP TABLE if not exists t
	(
		tplaca text,
		tregiao text,
		ttipo text
	/*	vencimento_seguro date, 
		vistoria_data date, 
		contrato_codigo integer, 
		contrato_vencimento date, 
		validade_taxa date, 
		empresa text*/
	)
	ON COMMIT DROP;

	total := 0;

	open c for select distinct veiculo.placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento < current_date) and (data_exclusao_fretamento is null or data_exclusao_fretamento > current_date);
	loop
		fetch c into r;
		exit when not found;

		_contrato_codigo := fretamento.pega_contrato(r.placa, current_date);

		_seguro := fretamento.veiculo_validade_seguro(r.placa);

		_laudo := fretamento.veiculo_validade_laudo(r.placa, current_date);

		_taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);

		_contrato := fretamento.veiculo_validade_contrato(_contrato_codigo, current_date);
	
		_regiao := fretamento.pega_regiao(r.placa);

		_servico := fretamento.servico(_contrato_codigo);

		bom := 0;
		
		if _seguro is not null and _seguro > current_date then
			bom := bom + 1;
		end if;
		if _laudo is not null and _laudo > current_date then
			bom := bom + 1;
		end if;
		if _taxa is not null and _taxa > current_date then
			bom := bom + 1;
		end if;
		if _contrato is not null and _contrato > current_date then
			bom := bom + 1;
		end if;

		if bom = 4 then
			insert into t (tplaca, tregiao, ttipo) values(r.placa, _regiao, fretamento.pega_tipo(r.placa));
		end if;
		
	end loop;

	return query select * from t;

	
end;
$$;


ALTER FUNCTION fretamento.rel_tipo_regiao() OWNER TO metroplan;

--
-- Name: _rel_total; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE UNLOGGED TABLE fretamento._rel_total (
    placa text NOT NULL,
    regiao text,
    contrato_codigo integer,
    contrato date,
    seguro date,
    taxa date,
    laudo date,
    cnpj text,
    empresa text,
    lugares integer,
    ano_fabricacao integer,
    modelo text,
    tipo text
);


ALTER TABLE fretamento._rel_total OWNER TO metroplan;

--
-- Name: TABLE _rel_total; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON TABLE fretamento._rel_total IS 'unlogged table = maior performance
usada pra facilitar a adaptação do registra_historico(), que daria mais trabalho fazer retornar uma tabela com puro codigo.
idealmente fazer da forma correta no futuro';


--
-- Name: rel_total(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.rel_total() RETURNS SETOF fretamento._rel_total
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
_contrato_codigo integer;
_taxa date;
_laudo date;
_seguro date;
_contrato date;
_regiao text;
_empresa text;
_cnpj text;
_lugares integer;
_ano integer;
_modelo text;
_tipo text;
total integer;
bom integer;
data_corte date;
begin

	total := 0;

	data_corte := current_date  - INTERVAL '2 years';

	delete from fretamento._rel_total;
	
	open c for select distinct placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento <= current_date) and (data_exclusao_fretamento is null or data_exclusao_fretamento > current_date);
	loop
		fetch c into r;
		exit when not found;

		_contrato_codigo := fretamento.pega_contrato(r.placa);
		if _contrato_codigo is null then
			RAISE NOTICE '[%]', _contrato_codigo;
			_contrato_codigo := fretamento.pega_contrato_forca(r.placa);
			RAISE NOTICE '[%]', _contrato_codigo;
		end if;

		_seguro := fretamento.veiculo_validade_seguro(r.placa);

		_laudo := fretamento.veiculo_validade_laudo(r.placa);

		_taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);

		_contrato := fretamento.veiculo_validade_contrato(_contrato_codigo);
	
		_regiao := fretamento.pega_regiao(r.placa);

		_lugares := fretamento.lugares_contrato(_contrato_codigo);

		_ano := fretamento.ano_fabricacao(r.placa);

		_modelo := fretamento.modelo(r.placa);

		_tipo := fretamento.tipo(r.placa);


		bom := 0;
		
		if _seguro is not null and _seguro > data_corte then
			bom := bom + 1;
		end if;
		if _laudo is not null and _laudo > data_corte then
			bom := bom + 1;
		end if;
		if _taxa is not null and _taxa > data_corte then
			bom := bom + 1;
		end if;
		if _contrato is not null and _contrato > data_corte then
			bom := bom + 1;
		end if;
		
		if bom > 0 then

			_cnpj := (fretamento.pega_empresa(r.placa));
			_empresa := (fretamento.pega_empresa_nome(r.placa));

			insert into fretamento._rel_total (placa, regiao, contrato_codigo, contrato, seguro, taxa, laudo, empresa, cnpj, lugares, ano_fabricacao, modelo, tipo)
			values(r.placa, _regiao, _contrato_codigo, _contrato, _seguro, _taxa, _laudo, _empresa, _cnpj, _lugares, _ano, _modelo, _tipo);
			total := total + 1;
		end if;
	end loop;


	return query select * from fretamento._rel_total order by regiao, empresa, placa;
	
end;
$$;


ALTER FUNCTION fretamento.rel_total() OWNER TO metroplan;

--
-- Name: relatorio_numero_passageiros(text, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.relatorio_numero_passageiros(regiao text, servico text) RETURNS TABLE(codigo integer, regiao text, servico text, passageiros bigint)
    LANGUAGE sql STABLE
    AS $_$

select codigo, regiao_codigo, servico_nome, sum(numero_passageiros) from fretamento.contrato
where ($1 is null or regiao_codigo = $1) and ($2 is null or servico_nome = $2)
and regiao_codigo is not null and servico_nome is not null
and data_fim > now()::date
group by regiao_codigo, servico_nome, codigo
order by regiao_codigo, servico_nome, codigo


$_$;


ALTER FUNCTION fretamento.relatorio_numero_passageiros(regiao text, servico text) OWNER TO metroplan;

--
-- Name: relatorio_veiculos(boolean, text, text, text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.relatorio_veiculos(boolean, text, text, text) RETURNS TABLE(placa text, empresa text, regiao text, tipo text, situacao text)
    LANGUAGE sql STABLE
    AS $_$

-- $1 -> ativo (t, f or null)
-- $2 -> tipo veiculo
-- $3 -> regiao
-- $4 -> coluna de ordenacao

select veiculo_placa, nome, regiao_codigo, fretamento_veiculo_tipo_nome, situacao from
(
select codigo, veiculo_placa, empresa.nome, empresa.regiao_codigo, veiculo.fretamento_veiculo_tipo_nome,
case when fretamento.checa_tudo(codigo, veiculo_placa) = false then 'Inativo' else 'Ativo' end as situacao
from fretamento.contrato, geral.veiculo, geral.empresa, fretamento.contrato_itinerario
where contrato.codigo = contrato_itinerario.contrato_codigo
and veiculo.empresa_cnpj = empresa.cnpj
and veiculo.placa = contrato_itinerario.veiculo_placa
and veiculo.data_inclusao_fretamento is not null
and ($2 is null or veiculo.fretamento_veiculo_tipo_nome = $2)
and ($3 is null or empresa.regiao_codigo = $3)
and ($1 is null or fretamento.checa_tudo(codigo, veiculo_placa) = $1)

group by codigo, veiculo_placa, empresa.nome, empresa.regiao_codigo, veiculo.fretamento_veiculo_tipo_nome
) as x
group by veiculo_placa, nome, regiao_codigo, fretamento_veiculo_tipo_nome, situacao
order by 
case when $4 = '2' then veiculo_placa end,
case when $4 = '3' then nome end,
case when $4 = '4' then regiao_codigo end,
case when $4 = '5' then fretamento_veiculo_tipo_nome end

$_$;


ALTER FUNCTION fretamento.relatorio_veiculos(boolean, text, text, text) OWNER TO metroplan;

--
-- Name: seguro_vencido(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.seguro_vencido(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT

(select data_vencimento_seguro from geral.veiculo where placa = $1) < current_date

$_$;


ALTER FUNCTION fretamento.seguro_vencido(placa text) OWNER TO metroplan;

--
-- Name: servico(integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.servico(contrato integer) RETURNS text
    LANGUAGE sql STABLE
    AS $_$


select servico_nome from fretamento.contrato where contrato.codigo = $1


$_$;


ALTER FUNCTION fretamento.servico(contrato integer) OWNER TO metroplan;

--
-- Name: soma_lugares_regiao_servico(text, text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_lugares_regiao_servico(regiao text, servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select sum(numero_lugares)::integer from geral.veiculo where placa in (select distinct placa from fretamento.raiz_contagem_vencimentos 
where regiao_codigo = $1 and servico_nome = $2
and validade_seguro >= $3
and validade_contrato >= $3
and validade_laudo >= $3
and validade_autorizacao >= $3)


$_$;


ALTER FUNCTION fretamento.soma_lugares_regiao_servico(regiao text, servico text, data date) OWNER TO metroplan;

--
-- Name: soma_lugares_regiao_servico2(text, text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_lugares_regiao_servico2(regiao text, servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select sum(numero_lugares)::integer from geral.veiculo where placa in (select placa from fretamento.historico 
where regiao = $1  and servico = $2 and data = $3
and seguro > $3
and contrato > $3
and laudo > $3
and taxa > $3)


$_$;


ALTER FUNCTION fretamento.soma_lugares_regiao_servico2(regiao text, servico text, data date) OWNER TO metroplan;

--
-- Name: soma_lugares_servico(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_lugares_servico(servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select sum(numero_lugares)::integer from geral.veiculo where placa in (select distinct placa from fretamento.raiz_contagem_vencimentos 
where servico_nome = $1
and validade_seguro >= $2
and validade_contrato >= $2
and validade_laudo >= $2
and validade_autorizacao >= $2)


$_$;


ALTER FUNCTION fretamento.soma_lugares_servico(servico text, data date) OWNER TO metroplan;

--
-- Name: soma_lugares_servico2(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_lugares_servico2(servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select sum(numero_lugares)::integer from geral.veiculo where placa in (select placa from fretamento.historico 
where servico = $1 and data = $2
and seguro > $2
and contrato > $2
and laudo > $2
and taxa > $2)


$_$;


ALTER FUNCTION fretamento.soma_lugares_servico2(servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros(servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select total_passageiros::integer from (select sum(coalesce(numero_passageiros, 0)) as total_passageiros
from fretamento.contrato
where servico_nome = $1 and (regiao_codigo = 'RMPA' or regiao_codigo = 'RMSG' or regiao_codigo = 'AULINOR' or regiao_codigo = 'AUSUL')
and data_fim >= $2
) as total_passageiros



$_$;


ALTER FUNCTION fretamento.soma_passageiros(servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros(text, text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros(regiao text, servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select total_passageiros::integer from (select count(codigo), regiao_codigo, servico_nome, sum(numero_passageiros) as total_passageiros
from fretamento.contrato
where regiao_codigo = $1 and servico_nome = $2
and data_fim >= $3
group by regiao_codigo, servico_nome
order by regiao_codigo, servico_nome) as x



$_$;


ALTER FUNCTION fretamento.soma_passageiros(regiao text, servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros_regiao_servico(text, text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros_regiao_servico(regiao text, servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select sum(numero_passageiros)::integer from fretamento.contrato where codigo in (select distinct contrato_codigo from fretamento.raiz_contagem_vencimentos 
where regiao_codigo = $1 and servico_nome = $2
and validade_seguro >= current_date
and validade_contrato >= current_date
and validade_laudo >= current_date
and validade_autorizacao >= current_date
)




$_$;


ALTER FUNCTION fretamento.soma_passageiros_regiao_servico(regiao text, servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros_regiao_servico2(text, text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros_regiao_servico2(regiao text, servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select sum(passageiros)::integer from fretamento.historico where regiao = $1 and servico = $2
and data = $3
and seguro > $3
and contrato > $3
and laudo > $3
and taxa > $3


$_$;


ALTER FUNCTION fretamento.soma_passageiros_regiao_servico2(regiao text, servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros_regiao_servico3(text, text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros_regiao_servico3(regiao text, servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

/*select sum(passageiros)::integer from fretamento.historico where regiao = $1 and servico = $2
and data = $3
and seguro > $3
and contrato > $3
and laudo > $3
and taxa > $3*/


select sum(numero_passageiros)::integer from fretamento.contrato where regiao_codigo = $1 and servico_nome = $2
and $3 between data_inicio and data_fim


$_$;


ALTER FUNCTION fretamento.soma_passageiros_regiao_servico3(regiao text, servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros_servico(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros_servico(servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select sum(numero_passageiros)::integer from fretamento.contrato where codigo in (select distinct contrato_codigo from fretamento.raiz_contagem_vencimentos 
where servico_nome = $1
and validade_seguro >= $2
and validade_contrato >= $2
and validade_laudo >= $2
and validade_autorizacao >= $2
)




$_$;


ALTER FUNCTION fretamento.soma_passageiros_servico(servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros_servico2(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros_servico2(servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

select sum(passageiros)::integer from fretamento.historico where servico = $1
and data = $2
and seguro > $2
and contrato > $2
and laudo > $2
and taxa > $2



$_$;


ALTER FUNCTION fretamento.soma_passageiros_servico2(servico text, data date) OWNER TO metroplan;

--
-- Name: soma_passageiros_servico3(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.soma_passageiros_servico3(servico text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$

/*select sum(passageiros)::integer from fretamento.historico where servico = $1
and data = $2
and seguro > $2
and contrato > $2
and laudo > $2
and taxa > $2*/

select sum(numero_passageiros)::integer from fretamento.contrato where servico_nome = $1
and $2 between data_inicio and data_fim



$_$;


ALTER FUNCTION fretamento.soma_passageiros_servico3(servico text, data date) OWNER TO metroplan;

--
-- Name: tem_divida(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.tem_divida(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

/*SELECT
(select count(*) 
from multas.devedor, geral.empresa, geral.veiculo
where veiculo.placa = $1 and veiculo.empresa_cnpj = empresa.cnpj
and devedor.empresa_cnpj = empresa.cnpj and devedor.baixa_divida = false
) > 0*/
SELECT
(select count(*) 
from multas.devedor, geral.empresa, geral.veiculo
where veiculo.placa = $1 and veiculo.empresa_cnpj = empresa.cnpj
and devedor.empresa_cnpj = empresa.cnpj and devedor.baixa_divida = false
) > 0 
or
(select count(*)
from geral.veiculo, multas.devedor,geral.empresa, geral.empresa_codigo
where veiculo.empresa_cnpj is null
and empresa.cnpj = devedor.empresa_cnpj and
veiculo.empresa_codigo_codigo = empresa_codigo.codigo
and veiculo.placa = $1
and baixa_divida = false

) > 0
or
(select count(*) from geral.empresa, multas.devedor 
where empresa.cnpj = devedor.empresa_cnpj and baixa_divida = false and cnpj = $1
) > 0



$_$;


ALTER FUNCTION fretamento.tem_divida(placa text) OWNER TO metroplan;

--
-- Name: tipo(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.tipo(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select fretamento_veiculo_tipo_nome from geral.veiculo where veiculo.placa = $1;
$_$;


ALTER FUNCTION fretamento.tipo(placa text) OWNER TO metroplan;

--
-- Name: total(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.total() RETURNS integer
    LANGUAGE sql STABLE
    AS $$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null
and (validade_seguro >= current_date
			or validade_contrato >= current_date
			or validade_laudo >= current_date
			or validade_autorizacao >= current_date)



$$;


ALTER FUNCTION fretamento.total() OWNER TO metroplan;

--
-- Name: total(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.total(data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null
and (validade_seguro >= data
			or validade_contrato >= data
			or validade_laudo >= data
			or validade_autorizacao >= data)



$$;


ALTER FUNCTION fretamento.total(data date) OWNER TO metroplan;

--
-- Name: total(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.total(regiao text) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null and regiao_codigo = $1
and (validade_seguro >= current_date
			or validade_contrato >= current_date
			or validade_laudo >= current_date
			or validade_autorizacao >= current_date)



$_$;


ALTER FUNCTION fretamento.total(regiao text) OWNER TO metroplan;

--
-- Name: total(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.total(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz where data_exclusao_fretamento is null and regiao_codigo = $1
and (validade_seguro >= data
			or validade_contrato >= data
			or validade_laudo >= data
			or validade_autorizacao >= data)



$_$;


ALTER FUNCTION fretamento.total(regiao text, data date) OWNER TO metroplan;

--
-- Name: total_rapido(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.total_rapido(regiao text, data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
begin

	total := 0;

	open c for select distinct placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento <= data) and (data_exclusao_fretamento is null or data_exclusao_fretamento > data);
	loop
		fetch c into r;
		exit when not found;

		if (fretamento.pertence(r.placa, regiao)) = false then
			continue;
		end if;

		contrato := fretamento.pega_contrato(r.placa, data);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) >= data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa, data) >= data then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, contrato) >= data then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(contrato, data) >= data then
			i:= i + 1;
		end if;

		if i > 0 then
			total := total + 1;
		end if;
	
	end loop;

	return total;

end;
$$;


ALTER FUNCTION fretamento.total_rapido(regiao text, data date) OWNER TO metroplan;

--
-- Name: total_rapido2(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.total_rapido2(_regiao text, _data date) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$

declare
c refcursor;
r record;
total integer;
i integer;
contrato integer;
begin

	total := 0;

	open c for select * from fretamento.historico where regiao = _regiao and data = _data;
	loop
		fetch c into r;
		exit when not found;
		i := 0;

		if r.seguro > _data then
			i:= i + 1;
		end if;

		if r.taxa > _data then
			i:= i + 1;
		end if;

		if r.contrato > _data then
			--i:= i + 1;
		end if;

		if r.laudo > _data then
			i:= i + 1;
		end if;



		if i > 0 then
			total := total + 1;
		end if;
	
	end loop;

	return total;

end;
$$;


ALTER FUNCTION fretamento.total_rapido2(_regiao text, _data date) OWNER TO metroplan;

--
-- Name: upper_contratante(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.upper_contratante() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.nome = upper(trim(NEW.nome));
	NEW.observacoes = upper(trim(NEW.observacoes));
	return NEW;
END;$$;


ALTER FUNCTION fretamento.upper_contratante() OWNER TO metroplan;

--
-- Name: upper_contrato(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.upper_contrato() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.observacoes = upper(trim(NEW.observacoes));
	return NEW;
END;$$;


ALTER FUNCTION fretamento.upper_contrato() OWNER TO metroplan;

--
-- Name: upper_entidade(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.upper_entidade() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.nome = upper(trim(NEW.nome));
	return NEW;
END;$$;


ALTER FUNCTION fretamento.upper_entidade() OWNER TO metroplan;

--
-- Name: veiculo_cadastrado(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_cadastrado(_placa text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
_contrato_codigo integer;
_taxa date;
_laudo date;
_seguro date;
_contrato date;
begin
	open c for select distinct placa from geral.veiculo where placa = _placa and (data_inclusao_fretamento is not null and data_inclusao_fretamento <= current_date) and (data_exclusao_fretamento is null or data_exclusao_fretamento > current_date);
	
		fetch c into r;
		if r is null then 
			return false;
		end if;

		_seguro := fretamento.veiculo_validade_seguro(r.placa);
		if _seguro is not null and _seguro > current_date then
			return true;
		end if;
		_laudo := fretamento.veiculo_validade_laudo(r.placa, current_date);
		if _laudo is not null and _laudo > current_date then
			return true;
		end if;

		_contrato_codigo := fretamento.pega_contrato(r.placa, current_date);
		_contrato := fretamento.veiculo_validade_contrato(_contrato_codigo, current_date);
		if _contrato is not null and _contrato > current_date then
			return true;
		end if;

		_taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);
		if _taxa is not null and _taxa > current_date then
			return true;
		end if;


	return false;
	
end;
$$;


ALTER FUNCTION fretamento.veiculo_cadastrado(_placa text) OWNER TO metroplan;

--
-- Name: veiculo_excluido(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_excluido(placa text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $_$

SELECT
(select data_exclusao_fretamento from geral.veiculo where placa = $1) <= current_date


$_$;


ALTER FUNCTION fretamento.veiculo_excluido(placa text) OWNER TO metroplan;

--
-- Name: veiculo_inicio_contrato(integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_inicio_contrato(ct integer) RETURNS date
    LANGUAGE sql STABLE
    AS $_$

select contrato.data_inicio as data_inicio from fretamento.contrato where codigo = $1;


$_$;


ALTER FUNCTION fretamento.veiculo_inicio_contrato(ct integer) OWNER TO metroplan;

--
-- Name: veiculo_validade_autorizacao(text, integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_validade_autorizacao(pl text, ct integer) RETURNS date
    LANGUAGE sql STABLE
    AS $_$

select (autorizacao.data_inicio + interval '1 year')::date from fretamento.autorizacao
		WHERE autorizacao.contrato_codigo = $2
		AND autorizacao.veiculo_placa = $1 order by autorizacao.data_inicio desc


$_$;


ALTER FUNCTION fretamento.veiculo_validade_autorizacao(pl text, ct integer) OWNER TO metroplan;

--
-- Name: veiculo_validade_contrato(integer); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_validade_contrato(ct integer) RETURNS date
    LANGUAGE sql STABLE
    AS $_$

select contrato.data_fim as validade_contrato from fretamento.contrato where codigo = $1;


$_$;


ALTER FUNCTION fretamento.veiculo_validade_contrato(ct integer) OWNER TO metroplan;

--
-- Name: veiculo_validade_contrato(integer, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_validade_contrato(ct integer, data date) RETURNS date
    LANGUAGE sql STABLE
    AS $_$

select contrato.data_fim as validade_contrato from fretamento.contrato where codigo = $1
and data between data_inicio and data_fim;


$_$;


ALTER FUNCTION fretamento.veiculo_validade_contrato(ct integer, data date) OWNER TO metroplan;

--
-- Name: veiculo_validade_laudo(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_validade_laudo(pl text) RETURNS date
    LANGUAGE sql STABLE
    AS $_$

SELECT laudo_vistoria.data_validade from fretamento.laudo_vistoria where veiculo_placa = $1
order by data_validade desc

$_$;


ALTER FUNCTION fretamento.veiculo_validade_laudo(pl text) OWNER TO metroplan;

--
-- Name: veiculo_validade_laudo(text, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_validade_laudo(pl text, data date) RETURNS date
    LANGUAGE sql STABLE
    AS $_$

SELECT laudo_vistoria.data_validade from fretamento.laudo_vistoria where veiculo_placa = $1
and data_emissao < data
order by data_validade desc

$_$;


ALTER FUNCTION fretamento.veiculo_validade_laudo(pl text, data date) OWNER TO metroplan;

--
-- Name: veiculo_validade_seguro(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_validade_seguro(pl text) RETURNS date
    LANGUAGE sql STABLE
    AS $_$

SELECT data_vencimento_seguro as validade_seguro from geral.veiculo where placa = $1;

$_$;


ALTER FUNCTION fretamento.veiculo_validade_seguro(pl text) OWNER TO metroplan;

--
-- Name: veiculo_valido(text); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculo_valido(_placa text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$

DECLARE
    c refcursor;
    r record;
    _contrato_codigo integer;
    _taxa date;
    _laudo date;
    _seguro date;
    _contrato date;
BEGIN
    OPEN c FOR
        SELECT DISTINCT placa
        FROM geral.veiculo
        WHERE placa = _placa
          AND (data_inclusao_fretamento IS NOT NULL AND data_inclusao_fretamento <= current_date)
          AND (data_exclusao_fretamento IS NULL OR data_exclusao_fretamento > current_date);

    FETCH c INTO r;
    IF r IS NULL THEN
        RETURN false;
    END IF;

    _seguro := fretamento.veiculo_validade_seguro(r.placa);
    _laudo := fretamento.veiculo_validade_laudo(r.placa, current_date);
    _contrato_codigo := fretamento.pega_contrato(r.placa, current_date);
    _contrato := fretamento.veiculo_validade_contrato(_contrato_codigo, current_date);
    _taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);

    IF _seguro IS NOT NULL AND _seguro > current_date
       AND _laudo IS NOT NULL AND _laudo > current_date
       AND _contrato IS NOT NULL AND _contrato > current_date
       AND _taxa IS NOT NULL AND _taxa > current_date THEN
        RETURN true;
    ELSE
        RETURN false;
    END IF;

END;
$$;


ALTER FUNCTION fretamento.veiculo_valido(_placa text) OWNER TO metroplan;

--
-- Name: veiculos_sublocacao(); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.veiculos_sublocacao() RETURNS TABLE(placa text, empresa text, subcontratado text)
    LANGUAGE plpgsql
    AS $$

declare
c refcursor;
r record;
_contrato_codigo integer;
_taxa date;
_laudo date;
_seguro date;
_contrato date;
_regiao text;
_empresa text;
_servico text;
_passageiros integer;
_lugares integer;
total integer;
bom integer;

begin

	CREATE TEMP TABLE if not exists t
	(
		placa text,
		empresa text,
		subcontratado text
	)
	ON COMMIT DROP;

	total := 0;

	open c for select distinct veiculo.placa from geral.veiculo where (data_inclusao_fretamento is not null and data_inclusao_fretamento <= current_date) and (data_exclusao_fretamento is null or data_exclusao_fretamento > current_date);
	loop
		fetch c into r;
		exit when not found;

		_contrato_codigo := fretamento.pega_contrato(r.placa, current_date);

		_seguro := fretamento.veiculo_validade_seguro(r.placa);

		_laudo := fretamento.veiculo_validade_laudo(r.placa, current_date);

		_taxa := fretamento.veiculo_validade_autorizacao(r.placa, _contrato_codigo);

		_contrato := fretamento.veiculo_validade_contrato(_contrato_codigo, current_date);

		_empresa := (fretamento.pega_empresa_nome(r.placa));

		_regiao := fretamento.pega_regiao(r.placa);
  
		bom := 0;
		
		if _seguro is not null and _seguro > current_date then
			bom := bom + 1;
		end if;
		if  bom = 0 and _laudo is not null and _laudo > current_date then
			bom := bom + 1;
		end if;
		if bom = 0 and _taxa is not null and _taxa > current_date then
			bom := bom + 1;
		end if;
		if bom = 0 and _contrato is not null and _contrato > current_date then
			bom := bom + 1;
		end if;
		
		if bom > 0 and _regiao is not null then
			insert into t (placa, empresa, subcontratado) values (r.placa, _empresa, fretamento.pega_subcontratado2(r.placa));
		end if;
	end loop;

	return query select * from t;
	
end;
$$;


ALTER FUNCTION fretamento.veiculos_sublocacao() OWNER TO metroplan;

--
-- Name: vencidos_periodo(date, date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.vencidos_periodo(inicio date, fim date) RETURNS TABLE(placa text, contrato text, laudo_validade date, seguro_validade date, contrato_validade date, autorizacao_validade date, municipio_chegada text, empresa text, contratante text)
    LANGUAGE sql STABLE
    AS $_$

select placa, contrato::text, laudo_validade, seguro_validade, contrato_validade, autorizacao_validade, municipio_chegada
,(select nome from geral.empresa, geral.veiculo where veiculo.placa = main.placa and veiculo.empresa_cnpj = empresa.cnpj) as empresa
,(select nome from fretamento.contratante where contratante.codigo = contrato.contratante_codigo)
from fretamento.lista_vencimento_placas as main, fretamento.contratante, fretamento.contrato


where ((laudo_validade between $1 and $2) 
or (seguro_validade between $1 and $2) 
or (contrato_validade between $1 and $2) 
or (autorizacao_validade between $1 and $2))
and contrato.contratante_codigo = contratante.codigo
and contrato.codigo = contrato

$_$;


ALTER FUNCTION fretamento.vencidos_periodo(inicio date, fim date) OWNER TO metroplan;

--
-- Name: vencidos_periodo2(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.vencidos_periodo2(fim date) RETURNS TABLE(placa text, contrato text, laudo_validade date, seguro_validade date, contrato_validade date, autorizacao_validade date, municipio_chegada text, empresa text, contratante text)
    LANGUAGE plpgsql
    AS $$
declare
c refcursor;
r record;
_contrato integer;
i integer;
muni text;
emp text;
lau date;
aut date;
seg date;
con date;
begin



	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(
		placa text, 
		contrato text, 
		laudo_validade date, 
		seguro_validade date, 
		contrato_validade date, 
		autorizacao_validade date, 
		municipio_chegada text, 
		empresa text, 
		contratante text
	)
	ON COMMIT DROP;

																			
	open c for select veiculo.placa from geral.veiculo where data_inclusao_fretamento is not null and (data_exclusao_fretamento is null or data_exclusao_fretamento > fim);


	loop
		fetch c into r;
		exit when not found;


		_contrato := fretamento.pega_contrato(r.placa);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < fim then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < fim then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, _contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, _contrato) < fim then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(_contrato) is null or fretamento.veiculo_validade_contrato(_contrato) < fim then
			i:= i + 1;
		end if;

		/*if i < 4 then
			insert into t (p, r, i) values (r.placa, r.regiao_codigo, (extract(year from current_date) - r.ano_fabricacao));
			
		end if;*/

		if i < 4 and i > 0 then

			lau := fretamento.veiculo_validade_laudo(r.placa);
			aut := fretamento.veiculo_validade_autorizacao(r.placa, _contrato);
			seg := fretamento.veiculo_validade_seguro(r.placa);
			con := fretamento.veiculo_validade_contrato(_contrato);

			muni := ( SELECT contrato_itinerario.municipio_nome_chegada
				FROM fretamento.contrato_itinerario, fretamento.autorizacao
				WHERE contrato_itinerario.contrato_codigo = autorizacao.contrato_codigo AND autorizacao.veiculo_placa = contrato_itinerario.veiculo_placa AND autorizacao.veiculo_placa = r.placa
				ORDER BY autorizacao.data_inicio DESC
				LIMIT 1);

			emp := (select nome from geral.empresa, geral.veiculo where veiculo.placa = r.placa and veiculo.empresa_cnpj = empresa.cnpj);

			contratante := (select nome from fretamento.contratante, fretamento.contrato where contrato.codigo = _contrato and contratante.codigo = contrato.contratante_codigo);


			insert into t values (r.placa, contrato, lau, seg, con, aut, muni, emp, contratante);
		end if;
		

	end loop;

		--return query select reg, fretamento.total_rapido(reg, data),avg(idade)::float from ttab group by reg; 
		---return query select t.r, fretamento.total_rapido(t.r, data), avg(t.i)::float from t group by t.r;
		return query select * from t order by municipio_chegada, empresa;

end
$$;


ALTER FUNCTION fretamento.vencidos_periodo2(fim date) OWNER TO metroplan;

--
-- Name: vencidos_periodo3(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.vencidos_periodo3(fim date) RETURNS TABLE(placa text, contrato text, laudo_validade date, seguro_validade date, contrato_validade date, autorizacao_validade date, municipio_chegada text, empresa text, contratante text)
    LANGUAGE plpgsql
    AS $$
declare
c refcursor;
r record;
_contrato integer;
contrato_valido boolean;
i integer;
muni text;
emp text;
lau date;
aut date;
seg date;
con date;
begin



	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(
		placa text, 
		contrato text, 
		laudo_validade date, 
		seguro_validade date, 
		contrato_validade date, 
		autorizacao_validade date, 
		municipio_chegada text, 
		empresa text, 
		contratante text
	)
	ON COMMIT DROP;

																			
	open c for select veiculo.placa from geral.veiculo where data_inclusao_fretamento is not null and (data_exclusao_fretamento is null or data_exclusao_fretamento > fim);


	loop
		fetch c into r;
		exit when not found;

		contrato_valido := false;
		_contrato := fretamento.pega_contrato(r.placa);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < fim then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < fim then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, _contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, _contrato) < fim then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(_contrato) is null or fretamento.veiculo_validade_contrato(_contrato) < fim then
			--i:= i + 1;
			contrato_valido := true;
		end if;

		/*if i < 4 then
			insert into t (p, r, i) values (r.placa, r.regiao_codigo, (extract(year from current_date) - r.ano_fabricacao));
			
		end if;*/

		if i = 3 and contrato_valido = true then
			--carro bom
			continue;
		end if;

		if fretamento.veiculo_validade_contrato(_contrato) is null then
			continue;
		end if;



		if i < 3 and i > 0 then

			lau := fretamento.veiculo_validade_laudo(r.placa);
			aut := fretamento.veiculo_validade_autorizacao(r.placa, _contrato);
			seg := fretamento.veiculo_validade_seguro(r.placa);
			con := fretamento.veiculo_validade_contrato(_contrato);

			muni := ( SELECT contrato_itinerario.municipio_nome_chegada
				FROM fretamento.contrato_itinerario, fretamento.autorizacao
				WHERE contrato_itinerario.contrato_codigo = autorizacao.contrato_codigo AND autorizacao.veiculo_placa = contrato_itinerario.veiculo_placa AND autorizacao.veiculo_placa = r.placa
				ORDER BY autorizacao.data_inicio DESC
				LIMIT 1);

			emp := (select nome from geral.empresa, geral.veiculo where veiculo.placa = r.placa and veiculo.empresa_cnpj = empresa.cnpj);

			contratante := (select nome from fretamento.contratante, fretamento.contrato where contrato.codigo = _contrato and contratante.codigo = contrato.contratante_codigo);


			insert into t values (r.placa, contrato, lau, seg, con, aut, muni, emp, contratante);
		end if;
		

	end loop;

		--return query select reg, fretamento.total_rapido(reg, data),avg(idade)::float from ttab group by reg; 
		---return query select t.r, fretamento.total_rapido(t.r, data), avg(t.i)::float from t group by t.r;
		return query select * from t order by placa;--, municipio_chegada, empresa;

end
$$;


ALTER FUNCTION fretamento.vencidos_periodo3(fim date) OWNER TO metroplan;

--
-- Name: vencidos_periodo4(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.vencidos_periodo4(fim date) RETURNS TABLE(placa text, contrato text, laudo_validade date, seguro_validade date, contrato_validade date, autorizacao_validade date, municipio_chegada text, empresa text, contratante text)
    LANGUAGE plpgsql
    AS $$
declare
c refcursor;
r record;
_contrato integer;
contrato_valido boolean;
i integer;
muni text;
emp text;
lau date;
aut date;
seg date;
con date;
begin



	DROP TABLE IF EXISTS t;
	CREATE TEMP TABLE t 
	(
		placa text, 
		contrato text, 
		laudo_validade date, 
		seguro_validade date, 
		contrato_validade date, 
		autorizacao_validade date, 
		municipio_chegada text, 
		empresa text, 
		contratante text
	)
	ON COMMIT DROP;

																			
	open c for select veiculo.placa from geral.veiculo where data_inclusao_fretamento is not null and (data_exclusao_fretamento is null or data_exclusao_fretamento > fim);


	loop
		fetch c into r;
		exit when not found;

		contrato_valido := false;
		_contrato := fretamento.pega_contrato(r.placa);

		i := 0;

		if fretamento.veiculo_validade_seguro(r.placa) is null or fretamento.veiculo_validade_seguro(r.placa) < fim then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_laudo(r.placa) is null or fretamento.veiculo_validade_laudo(r.placa) < fim then
			i:= i + 1;
		end if;

		if fretamento.veiculo_validade_autorizacao(r.placa, _contrato) is null or fretamento.veiculo_validade_autorizacao(r.placa, _contrato) < fim then
			i:= i + 1;
		end if;


		if fretamento.veiculo_validade_contrato(_contrato) is null or fretamento.veiculo_validade_contrato(_contrato) < fim then
			--i:= i + 1;
			contrato_valido := true;
		end if;

		/*if i < 4 then
			insert into t (p, r, i) values (r.placa, r.regiao_codigo, (extract(year from current_date) - r.ano_fabricacao));
			
		end if;*/

		if i = 3 and contrato_valido = true then
			--carro bom
			continue;
		end if;

		if fretamento.veiculo_validade_contrato(_contrato) is null then
			continue;
		end if;



		if i < 3 and i > 0 then

			lau := fretamento.veiculo_validade_laudo(r.placa);
			if lau > fim then
				lau := null;
			end if;
			aut := fretamento.veiculo_validade_autorizacao(r.placa, _contrato);
			if aut > fim then
				aut := null;
			end if;
			seg := fretamento.veiculo_validade_seguro(r.placa);
			if seg > fim then
				seg := null;
			end if;
			con := fretamento.veiculo_validade_contrato(_contrato);
			if con > fim then
				con := null;
			end if;

			muni := ( SELECT contrato_itinerario.municipio_nome_chegada
				FROM fretamento.contrato_itinerario, fretamento.autorizacao
				WHERE contrato_itinerario.contrato_codigo = autorizacao.contrato_codigo AND autorizacao.veiculo_placa = contrato_itinerario.veiculo_placa AND autorizacao.veiculo_placa = r.placa
				ORDER BY autorizacao.data_inicio DESC
				LIMIT 1);

			emp := (select nome from geral.empresa, geral.veiculo where veiculo.placa = r.placa and veiculo.empresa_cnpj = empresa.cnpj);

			contratante := (select nome from fretamento.contratante, fretamento.contrato where contrato.codigo = _contrato and contratante.codigo = contrato.contratante_codigo);


			insert into t values (r.placa, contrato, lau, seg, con, aut, muni, emp, contratante);
		end if;
		

	end loop;

		return query select * from t order by placa;

end
$$;


ALTER FUNCTION fretamento.vencidos_periodo4(fim date) OWNER TO metroplan;

--
-- Name: vencidos_periodo5(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.vencidos_periodo5(fim date) RETURNS TABLE(placa text, contrato text, laudo_validade date, seguro_validade date, contrato_validade date, autorizacao_validade date, municipio_chegada text, empresa text, contratante text)
    LANGUAGE plpgsql STABLE
    AS $$
begin

return query select distinct historico.placa, fretamento.pega_contrato(historico.placa)::text, historico.laudo, historico.seguro, historico.contrato, historico.taxa,
--(select municipio_nome_chegada from fretamento.contrato_itinerario where veiculo_placa = historico.placa and contrato_codigo = fretamento.pega_contrato(placa)),

( SELECT contrato_itinerario.municipio_nome_chegada
				FROM fretamento.contrato_itinerario, fretamento.autorizacao
				WHERE contrato_itinerario.contrato_codigo = autorizacao.contrato_codigo AND autorizacao.veiculo_placa = contrato_itinerario.veiculo_placa AND autorizacao.veiculo_placa = historico.placa
				ORDER BY autorizacao.data_inicio DESC
				LIMIT 1) as municipio_chegada,

 nome_empresa_por_placa(historico.placa), 
(select identificacao_nome from fretamento.contratante, fretamento.contrato where contrato.contratante_codigo = contratante.codigo limit 1)
from fretamento.historico

where historico.placa in (select pla from fretamento.placas_pend(fim)) and historico.data = fim
order by placa
;




end;
$$;


ALTER FUNCTION fretamento.vencidos_periodo5(fim date) OWNER TO metroplan;

--
-- Name: vencidos_periodo6(date); Type: FUNCTION; Schema: fretamento; Owner: metroplan
--

CREATE FUNCTION fretamento.vencidos_periodo6(fim date) RETURNS TABLE(placa text, laudo_validade date, seguro_validade date, autorizacao_validade date, municipio_chegada text, empresa text)
    LANGUAGE plpgsql STABLE
    AS $$
begin

return query select distinct historico.placa, historico.laudo, historico.seguro, historico.taxa,
--(select municipio_nome_chegada from fretamento.contrato_itinerario where veiculo_placa = historico.placa and contrato_codigo = fretamento.pega_contrato(placa)),

( SELECT contrato_itinerario.municipio_nome_chegada
				FROM fretamento.contrato_itinerario, fretamento.autorizacao
				WHERE contrato_itinerario.contrato_codigo = autorizacao.contrato_codigo AND autorizacao.veiculo_placa = contrato_itinerario.veiculo_placa AND autorizacao.veiculo_placa = historico.placa
				ORDER BY autorizacao.data_inicio DESC
				LIMIT 1) as municipio_chegada,

 nome_empresa_por_placa(historico.placa)
from fretamento.historico

where historico.placa in (select pla from fretamento.placas_pend_ignora_contrato(fim)) and historico.data = fim
order by placa
;




end;
$$;


ALTER FUNCTION fretamento.vencidos_periodo6(fim date) OWNER TO metroplan;

--
-- Name: ativo(date, date); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.ativo(date, date) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
        select (now() between $1 and $2) or ($1 <= now() and $2 is null) or ($1 is null and $2 > now()) or ($1 is null and $2 is null);
$_$;


ALTER FUNCTION geral.ativo(date, date) OWNER TO metroplan;

--
-- Name: conta_dias_uteis(date, date); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.conta_dias_uteis(_inicio date, _fim date) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
total integer;
tmpdate date;
dia integer;
begin


	tmpdate := _inicio;
	total := 0;

	loop
	if (select tmpdate in (select data from geral.feriado)) then
		tmpdate := (select tmpdate + interval '1 day');
		continue;
	end if;
	
	dia := extract(dow from tmpdate);
	if dia <> 0 and dia <> 6 then total := total + 1; end if;
	if tmpdate >= _fim then
		exit;  
	end if;
	tmpdate := (select tmpdate + interval '1 day');
	end loop;

	return total;

end;
$$;


ALTER FUNCTION geral.conta_dias_uteis(_inicio date, _fim date) OWNER TO metroplan;

--
-- Name: conta_dias_uteis_parcial(date, date, integer); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.conta_dias_uteis_parcial(_inicio date, _fim date, _num integer) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
total integer;
tmpdate date;
dia integer;
parcial integer;
begin


	tmpdate := _inicio;
	total := 0;
	parcial = 0;
	
	loop
		if (select tmpdate in (select data from geral.feriado)) then
			tmpdate := (select tmpdate + interval '1 day'); --?
			continue;
		end if;
		
		if tmpdate >= _fim then
			exit;  
		end if;
		dia := extract(dow from tmpdate);
		if parcial < _num then
			if dia <> 0 and dia <> 6 then total := total + 1; end if;
		end if;
		tmpdate := (select tmpdate + interval '1 day');
		parcial := parcial + 1;
		if parcial = 5 then
			parcial := 0;
		end if;
		
	end loop;

	return total - 1; -- -1 pra bater com cálculos manuais do SEOPE

end;
$$;


ALTER FUNCTION geral.conta_dias_uteis_parcial(_inicio date, _fim date, _num integer) OWNER TO metroplan;

--
-- Name: conta_domingos(date, date); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.conta_domingos(_inicio date, _fim date) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
total integer;
tmpdate date;
dia integer;
begin


	tmpdate := _inicio;
	total := 0;
	
	loop
	if tmpdate in (select data from geral.feriado) then
		total := total + 1;
		tmpdate := (select tmpdate + interval '1 day');
		continue;
	end if;
	dia := extract(dow from tmpdate);
	if dia = 0 then total := total + 1; end if;
	if tmpdate >= _fim then
		exit;  
	end if;
	tmpdate := (select tmpdate + interval '1 day');
	end loop;

	return total;

end;
$$;


ALTER FUNCTION geral.conta_domingos(_inicio date, _fim date) OWNER TO metroplan;

--
-- Name: conta_emps_regiao(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.conta_emps_regiao(regiao text) RETURNS integer
    LANGUAGE sql
    AS $_$

	select count(distinct empresa_cnpj)::integer
	from geral.empresa_codigo, geral.empresa
	where empresa_codigo.regiao_codigo = $1
	and (data_exclusao is null or data_exclusao > current_date)
	and empresa.cnpj = empresa_codigo.empresa_cnpj
	--group by empresa_codigo.empresa_cnpj;

$_$;


ALTER FUNCTION geral.conta_emps_regiao(regiao text) OWNER TO metroplan;

--
-- Name: conta_sabados(date, date); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.conta_sabados(_inicio date, _fim date) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
declare
total integer;
tmpdate date;
dia integer;
begin


	tmpdate := _inicio;
	total := 0;
	
	loop
	dia := extract(dow from tmpdate);
	if dia = 6 then total := total + 1; end if;
	if tmpdate >= _fim then
		exit;  
	end if;
	tmpdate := (select tmpdate + interval '1 day');
	end loop;

	return total;

end;
$$;


ALTER FUNCTION geral.conta_sabados(_inicio date, _fim date) OWNER TO metroplan;

--
-- Name: eh_concessao(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.eh_concessao(placa text) RETURNS boolean
    LANGUAGE sql
    AS $_$

		select count(*) > 0 from geral.veiculo where placa = $1 and data_inclusao_concessao is not null
		and (data_exclusao_concessao is null or data_exclusao_concessao >= current_date)
	

$_$;


ALTER FUNCTION geral.eh_concessao(placa text) OWNER TO metroplan;

--
-- Name: eh_fretamento(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.eh_fretamento(placa text) RETURNS boolean
    LANGUAGE sql
    AS $_$

		select count(*) > 0 from geral.veiculo where placa = $1 and data_inclusao_fretamento is not null
		and (data_exclusao_fretamento is null or data_exclusao_fretamento >= current_date)
	

$_$;


ALTER FUNCTION geral.eh_fretamento(placa text) OWNER TO metroplan;

--
-- Name: formata_cep(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_cep(num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	/*return num.substring(0, 3) + "/" + num.substring(3, 5);
	select substr($1, 1, 3) || '/' || substr($1, 4, 2)

        return cnpj.substring(0, 2) + "." + cnpj.substring(2, 5) + "." +
                cnpj.substring(5, 8) + "/" + cnpj.substring(8, 12) + "-" +
                cnpj.substring(12, 14);
*/
	select substr($1, 1, 5) || '-' || substr($1, 6, 3)
	

$_$;


ALTER FUNCTION geral.formata_cep(num text) OWNER TO metroplan;

--
-- Name: formata_cnpj(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_cnpj(num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	/*return num.substring(0, 3) + "/" + num.substring(3, 5);
	select substr($1, 1, 3) || '/' || substr($1, 4, 2)

        return cnpj.substring(0, 2) + "." + cnpj.substring(2, 5) + "." +
                cnpj.substring(5, 8) + "/" + cnpj.substring(8, 12) + "-" +
                cnpj.substring(12, 14);
*/
	select substr($1, 1, 2) || '.' || substr($1, 3, 3) || '.' || substr($1, 6, 3) || '/' ||
		substr($1, 9, 4) || '-' || substr($1, 13, 2)
	

$_$;


ALTER FUNCTION geral.formata_cnpj(num text) OWNER TO metroplan;

--
-- Name: formata_cpf(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_cpf(num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

select substring($1 FROM 1 FOR 3) || '.' || substring($1 FROM 4 FOR 3) || '.' || substring($1 FROM 7 FOR 3) || '-' || substring($1 FROM 10 FOR 2);

$_$;


ALTER FUNCTION geral.formata_cpf(num text) OWNER TO metroplan;

--
-- Name: formata_dinheiro(numeric); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_dinheiro(valor numeric) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN REPLACE(valor::TEXT, '.'::TEXT, ','::TEXT);
END;
$$;


ALTER FUNCTION geral.formata_dinheiro(valor numeric) OWNER TO metroplan;

--
-- Name: formata_inscricao_estadual(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_inscricao_estadual(num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	/*return num.substring(0, 3) + "/" + num.substring(3, 5);
	select substr($1, 1, 3) || '/' || substr($1, 4, 2)

        return cnpj.substring(0, 2) + "." + cnpj.substring(2, 5) + "." +
                cnpj.substring(5, 8) + "/" + cnpj.substring(8, 12) + "-" +
                cnpj.substring(12, 14);
*/
	select substr($1, 1, 3) || '/' || substr($1, 4, 7)
	

$_$;


ALTER FUNCTION geral.formata_inscricao_estadual(num text) OWNER TO metroplan;

--
-- Name: formata_processo(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_processo(text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
declare 
len integer;
begin
	len = length($1);
	
	if len <> 11 then
		return $1;
	end if;

	--q q eh essa merda?!
	/*return substr($1, 1, len - 7) || '-' || substr($1, len - 6, 2) || '.' || substr($1, len - 4, 2) || '/' 
			|| substr($1, len - 2, 2) || '-' || substr($1, len, 1);*/
	
	--return substr($1, 1, 4) || '-13.64/' || substr($1, 5, 2) || '-' || substr($1, 7, 1);
	return substr($1, 1, 4) || '-' || substr($1, 5, 2) || '.' ||  substr($1, 7, 2) || '/' || substr($1, 9, 2) || '-' || substr($1, 11, 1);
	

end;
$_$;


ALTER FUNCTION geral.formata_processo(text) OWNER TO metroplan;

--
-- Name: formata_processo_velho(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_processo_velho(text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
declare 
len integer;
begin
	len = length($1);
	
	if len <> 7 then
		return $1;
	end if;

	--q q eh essa merda?!
	/*return substr($1, 1, len - 7) || '-' || substr($1, len - 6, 2) || '.' || substr($1, len - 4, 2) || '/' 
			|| substr($1, len - 2, 2) || '-' || substr($1, len, 1);*/
	
	return substr($1, 1, 4) || '-13.64/' || substr($1, 5, 2) || '-' || substr($1, 7, 1);
	

end;
$_$;


ALTER FUNCTION geral.formata_processo_velho(text) OWNER TO metroplan;

--
-- Name: formata_renavan(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_renavan(num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	select substr($1, 1, 8) || '-' || substr($1, 9, 1)
	

$_$;


ALTER FUNCTION geral.formata_renavan(num text) OWNER TO metroplan;

--
-- Name: formata_telefone(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.formata_telefone(num text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	--(12)3456-7890


	select '(' || substr($1, 1, 2) || ')' || substr($1, 3, 4) || '-' || substr($1, 7, 4)
	

$_$;


ALTER FUNCTION geral.formata_telefone(num text) OWNER TO metroplan;

--
-- Name: idade_chassi(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.idade_chassi(empresa_codigo text) RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $_$
        select AVG(EXTRACT(YEAR FROM CURRENT_DATE) - CHASSI_ANO) 
        from geral.veiculo, geral.empresa_codigo, geral.empresa
        where veiculo.empresa_codigo_codigo = empresa_codigo.codigo
        and empresa_codigo.codigo = $1
        and veiculo.empresa_codigo_codigo = empresa_codigo.codigo and empresa_codigo.empresa_cnpj = empresa.cnpj
and veiculo.data_inclusao_concessao is not null
and (data_exclusao_concessao is null or data_exclusao_concessao > current_date)
and (empresa.data_exclusao is null or empresa.data_exclusao > current_date)
and chassi_ano >= 1999


        
$_$;


ALTER FUNCTION geral.idade_chassi(empresa_codigo text) OWNER TO metroplan;

--
-- Name: idade_fabricacao(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.idade_fabricacao(placa text) RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $_$
        select extract(year from current_date) - ano_fabricacao
        from geral.veiculo
        where placa = $1


        
$_$;


ALTER FUNCTION geral.idade_fabricacao(placa text) OWNER TO metroplan;

--
-- Name: indice_urbanos_elevador(text); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.indice_urbanos_elevador(regiao text) RETURNS double precision
    LANGUAGE sql
    AS $_$

	select (sum(case when tem_elevador then 1 else 0 end)::float / count(*)::float * 100.0)::float from geral.veiculo, geral.empresa_codigo
	where empresa_codigo.regiao_codigo = $1 and veiculo.empresa_codigo_codigo = empresa_codigo.codigo
	and veiculo.classificacao_inmetro_nome = 'URBANO'
	and chassi_ano >= 1999 and data_inclusao_concessao is not null and regiao_codigo = $1
	

$_$;


ALTER FUNCTION geral.indice_urbanos_elevador(regiao text) OWNER TO metroplan;

--
-- Name: intersecta(date, date, date, date); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.intersecta(data_inclusao date, data_exclusao date, data_inicio date, data_fim date) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
--true se os pares de datas intersectam
--a segunda data de cada par pode ser nula, valendo como 'para sempre'
--se a terceira e quarta foram nulas mas a primeira nao, return true


-- diferente do _exclusao pq true $2 >= $3, nao apenas > 
--já $4 >= $1 não virou $4 > $1 porque o $4 nao é data de exclusao, é fim de periodo que foi selecionado, entao aquele dia vale

	select ($1 <= $3 and ($2 is null or $2 >= $3)) or ($3 <= $1 and ($4 is null or $4 >= $1))
		or ($3 is null and $4 is null and $1 is not null)


        
$_$;


ALTER FUNCTION geral.intersecta(data_inclusao date, data_exclusao date, data_inicio date, data_fim date) OWNER TO metroplan;

--
-- Name: intersecta_exclusao(date, date, date, date); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.intersecta_exclusao(data_inclusao date, data_exclusao date, data_inicio date, data_fim date) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$

--true se os pares de datas intersectam
--a segunda data de cada par pode ser nula, valendo como 'para sempre'
--se a terceira e quarta foram nulas mas a primeira nao, return true


--GERALMENTE VAI PRIMEIRO PASSAR INCLUSAO/EXLCUSAO, DEPOIS INPUT DESEJADO PRA COMPARAÇÃO
--e.g.: linha.inclusao, linha.exclusao, now, now
--FUNCAO intersecta() se desejar que a ordem das duplas nao altere resultado

--por fim, repare que TRUE vai indicar que a linha está ativa, não excluida

--$2 > $3 ao inves de $2 >= $3 porque o dia exato da data de exclusao ($2) não bate, pois naquele dia ela já não está valendo
--já $4 >= $1 não virou $4 > $1 porque o $4 nao é data de exclusao, é fim de periodo que foi selecionado, entao aquele dia vale

	select ($1 <= $3 and ($2 is null or $2 > $3)) or ($3 <= $1 and ($4 is null or $4 >= $1))
		or ($3 is null and $4 is null and $1 is not null)


        
$_$;


ALTER FUNCTION geral.intersecta_exclusao(data_inclusao date, data_exclusao date, data_inicio date, data_fim date) OWNER TO metroplan;

--
-- Name: intersecta_periodo(date, date, integer, integer, integer, integer); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.intersecta_periodo(data_inicio date, data_fim date, mes_inicio_periodo integer, dia_inicio_periodo integer, mes_fim_periodo integer, dia_fim_periodo integer) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
--REPARE A ASSIANTURA DA FUNCAO: PRIMEIRO MÊS, DEPOIS DIA
declare
mes_inicio int;
dia_inicio int;
mes_fim int;
dia_fim int;
abs_inicio int;
abs_fim int;
abs_inicio_periodo int;
abs_fim_periodo int;
begin

	if(data_fim is null) then
		return true;
	end if;

	if(data_inicio > data_fim) then
		return  null;
	end if;

	if (data_fim - data_inicio) >= 364 then
		return true;
	end if;

	mes_inicio := date_part('month', data_inicio);
	dia_inicio := date_part('day', data_inicio);
	mes_fim := date_part('month', data_fim);
	dia_fim := date_part('day', data_fim);
	
	abs_inicio := mes_inicio * 31 + dia_inicio;
	abs_fim := mes_fim * 31 + dia_fim;

	abs_inicio_periodo := mes_inicio_periodo * 31 + dia_inicio_periodo;
	abs_fim_periodo := mes_fim_periodo * 31 + dia_fim_periodo;


	if(abs_fim < abs_inicio and abs_fim_periodo < abs_inicio_periodo) then
		return true;
	end if;

	if(abs_fim < abs_inicio) then
		--return (abs_fim_periodo > abs_inicio or abs_inicio_periodo < abs_fim);
		return (abs_fim_periodo >= abs_inicio or abs_inicio_periodo <= abs_fim);
	end if;
	
	if(abs_fim_periodo < abs_inicio_periodo) then
		--return (abs_fim > abs_inicio_periodo or abs_inicio < abs_fim_periodo);
		return (abs_fim >= abs_inicio_periodo or abs_inicio <= abs_fim_periodo);
	end if;

	return (abs_inicio <= abs_inicio_periodo and abs_fim >= abs_inicio_periodo)
		--or (abs_inicio_periodo < abs_fim and abs_fim_periodo >= abs_fim);
		  or (abs_inicio_periodo < abs_fim and abs_fim_periodo >= abs_inicio);
	

end;
$$;


ALTER FUNCTION geral.intersecta_periodo(data_inicio date, data_fim date, mes_inicio_periodo integer, dia_inicio_periodo integer, mes_fim_periodo integer, dia_fim_periodo integer) OWNER TO metroplan;

--
-- Name: manda_vistoria_tabela(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.manda_vistoria_tabela() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
x integer;
begin

		insert into geral.veiculo_vistoria(veiculo_placa, data, data_vencimento) values(NEW.veiculo_placa, NEW.data, NEW.validade);
		return NEW;
end
$$;


ALTER FUNCTION geral.manda_vistoria_tabela() OWNER TO metroplan;

--
-- Name: numero_extenso(character); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.numero_extenso(num character) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
declare
w_cen integer ;
w_dez integer ;
w_dez2 integer ;
w_uni integer ;
w_tcen text ;
w_tdez text ;
w_tuni text ;
w_ext text ;
m_cen text[] := array['','cento','duzentos','trezentos','quatrocentos','quinhentos','seiscentos','setecentos','oitocentos','novecentos'];
m_dez text[] := array['','dez','vinte','trinta','quarenta','cinquenta','sessenta','setenta','oitenta','noventa'] ;
m_uni text[] := array['','um','dois','três','quatro','cinco','seis','sete','oito','nove','dez','onze','doze','treze','quatorze','quinze','dezesseis','dezessete','dezoito','dezenove'] ;
begin
  num := to_char(num::integer, 'FM000');
  w_cen := cast(substr(num,1,1) as integer) ;
  w_dez := cast(substr(num,2,1) as integer) ;
  w_dez2 := cast(substr(num,2,2) as integer) ;
  w_uni := cast(substr(num,3,1) as integer) ;
  if w_cen = 1 and w_dez2 = 0 then
     w_tcen := 'Cem' ;
     w_tdez := '' ;
     w_tuni := '' ;
    else
     if w_dez2 < 20 then
        w_tcen := m_cen[w_cen + 1] ;
        w_tdez := m_uni[w_dez2 + 1] ;
        w_tuni := '' ;
       else
        w_tcen := m_cen[w_cen + 1] ;
        w_tdez := m_dez[w_dez + 1] ;
        w_tuni := m_uni[w_uni + 1] ;
     end if ;   
  end if ;
  w_ext := w_tcen ;
  if w_tdez <> '' then 
     if w_ext = '' then
        w_ext := w_tdez ;
       else
        w_ext := w_ext || ' e ' || w_tdez ;
     end if ;     
  end if ;  
  if w_tuni <> '' then 
     if w_ext = '' then
        w_ext := w_tuni ;
       else
        w_ext := w_ext || ' e ' || w_tuni ;
     end if ;
  end if ;
  return w_ext ; 
end ;
$$;


ALTER FUNCTION geral.numero_extenso(num character) OWNER TO metroplan;

--
-- Name: proximo_veiculo_numero_alteracao(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.proximo_veiculo_numero_alteracao() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
num text;
begin
	num := (select ((substring(numero from 1 for length(numero)-2))::int+1)::text from geral.veiculo_alteracao 
		where numero is not null and
		substring(numero from '..$') = to_char(now(), 'yy')
		order by substring(numero from 1 for length(numero)-2) desc
		limit 1);
	if num is null then
		num := '001';
	end if;
	num := num || to_char(now(), 'yy');
	if length(num) < 5 then
		num := lpad(num, 5, '0');
	end if;
	
	return num;

end;
$_$;


ALTER FUNCTION geral.proximo_veiculo_numero_alteracao() OWNER TO metroplan;

--
-- Name: proximo_veiculo_numero_declaracao(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.proximo_veiculo_numero_declaracao() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
num text;
begin
	num := (select ((substring(numero from 1 for length(numero)-2))::int+1)::text from geral.veiculo_declaracao 
		where numero is not null and
		substring(numero from '..$') = to_char(now(), 'yy')
		order by substring(numero from 1 for length(numero)-2) desc
		limit 1);
	if num is null then
		num := '001';
	end if;
	num := num || to_char(now(), 'yy');
	if length(num) < 5 then
		num := lpad(num, 5, '0');
	end if;
	
	return num;

end;
$_$;


ALTER FUNCTION geral.proximo_veiculo_numero_declaracao() OWNER TO metroplan;

--
-- Name: proximo_veiculo_numero_exclusao(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.proximo_veiculo_numero_exclusao() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
num text;
begin

	LOCK TABLE geral.veiculo IN EXCLUSIVE MODE;


	num := (select ((substring(numero_exclusao from 1 for length(numero_exclusao)-2))::int+1)::text from geral.veiculo 
		where numero_exclusao is not null and
		substring(numero_exclusao from '..$') = to_char(now(), 'yy')
		order by substring(numero_exclusao from 1 for length(numero_exclusao)-2) desc
		limit 1);
	if num is null then
		num := '001';
	end if;
	num := num || to_char(now(), 'yy');
	if length(num) < 5 then
		num := lpad(num, 5, '0');
	end if;
	
	return num;

end;
$_$;


ALTER FUNCTION geral.proximo_veiculo_numero_exclusao() OWNER TO metroplan;

--
-- Name: proximo_veiculo_numero_inclusao(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.proximo_veiculo_numero_inclusao() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare
num text;
begin
	num := (select ((substring(numero_inclusao from 1 for length(numero_inclusao)-2))::int+1)::text from geral.veiculo 
		where numero_inclusao is not null and
		substring(numero_inclusao from '..$') = to_char(now(), 'yy')
		order by substring(numero_inclusao from 1 for length(numero_inclusao)-2) desc
		limit 1);
	if num is null then
		num := '001';
	end if;
	num := num || to_char(now(), 'yy');
	if length(num) < 5 then
		num := lpad(num, 5, '0');
	end if;
	
	return num;

end;
$_$;


ALTER FUNCTION geral.proximo_veiculo_numero_inclusao() OWNER TO metroplan;

--
-- Name: upper_codigo(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_codigo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.codigo = upper(trim(NEW.codigo));
	return NEW;
END;$$;


ALTER FUNCTION geral.upper_codigo() OWNER TO metroplan;

--
-- Name: upper_descricao(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_descricao() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.descricao = upper(trim(NEW.descricao));
	return NEW;
END;$$;


ALTER FUNCTION geral.upper_descricao() OWNER TO metroplan;

--
-- Name: upper_diretor(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_diretor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.diretor = upper(trim(NEW.diretor));
	return NEW;
END;$$;


ALTER FUNCTION geral.upper_diretor() OWNER TO metroplan;

--
-- Name: upper_empresa(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_empresa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.nome = upper(trim(NEW.nome));
	NEW.email = upper(trim(NEW.email));
	NEW.endereco = upper(trim(NEW.endereco));
	NEW.nome_simplificado = upper(trim(NEW.nome_simplificado));
	NEW.inscricao_estadual = upper(trim(NEW.inscricao_estadual));
	NEW.observacoes = upper(trim(NEW.observacoes));
	NEW.garagem_endereco = upper(trim(NEW.garagem_endereco));
	NEW.procurador = upper(trim(NEW.procurador));
	NEW.procurador_endereco = upper(trim(NEW.procurador_endereco));
	NEW.procurador_email = upper(trim(NEW.procurador_email));
	return NEW;
END;$$;


ALTER FUNCTION geral.upper_empresa() OWNER TO metroplan;

--
-- Name: upper_nome(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_nome() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.nome = upper(trim(NEW.nome));
	return NEW;
END;$$;


ALTER FUNCTION geral.upper_nome() OWNER TO metroplan;

--
-- Name: upper_observacoes(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_observacoes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.observacoes = upper(trim(NEW.observacoes));

	return NEW;
END;$$;


ALTER FUNCTION geral.upper_observacoes() OWNER TO metroplan;

--
-- Name: upper_veiculo(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_veiculo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.placa := upper(trim(NEW.placa));
	NEW.renavan := upper(trim(NEW.renavan));
	NEW.chassi_numero := upper(trim(NEW.chassi_numero));
	NEW.observacoes := upper(trim(NEW.observacoes));
	return NEW;
END;$$;


ALTER FUNCTION geral.upper_veiculo() OWNER TO metroplan;

--
-- Name: upper_vistoria(); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.upper_vistoria() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.engenheiro = upper(trim(NEW.engenheiro));
	NEW.oficina = upper(trim(NEW.oficina));
	return NEW;
END;$$;


ALTER FUNCTION geral.upper_vistoria() OWNER TO metroplan;

--
-- Name: uteis_ano(integer); Type: FUNCTION; Schema: geral; Owner: metroplan
--

CREATE FUNCTION geral.uteis_ano(ano integer) RETURNS TABLE(mes integer, uteis integer)
    LANGUAGE plpgsql
    AS $$
declare
total integer;
tmpdate date;
_dia integer;
_mes integer;
begin


	CREATE  TEMP TABLE if not exists t
	(
		mes integer,
		uteis integer
	)
	ON COMMIT DROP;



	tmpdate := (ano::text || '-01-01')::date;

	loop
		if extract (year from tmpdate) > ano then
			exit;  
		end if;

		if (select tmpdate in (select data from geral.feriado)) then
			tmpdate := (select tmpdate + interval '1 day');
			continue;
		end if;

		_dia := extract(dow from tmpdate);
		_mes := extract(mon from tmpdate);
		if _dia <> 0 and _dia <> 6 then 
			--total := total + 1; 
			insert into t values (_mes, 1);
		end if;
		
		tmpdate := (select tmpdate + interval '1 day');
	end loop;

	return query select t.mes, sum(t.uteis)::integer from t group by t.mes order by mes;

end;
$$;


ALTER FUNCTION geral.uteis_ano(ano integer) OWNER TO metroplan;

--
-- Name: distancia_ponto_ponto(point, point); Type: FUNCTION; Schema: gm; Owner: metroplan
--

CREATE FUNCTION gm.distancia_ponto_ponto(p1 point, p2 point) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
begin
	return sqrt( ((p1[0] - p2[0]) * (p1[0] - p2[0])) + ((p1[1] - p2[1]) * (p1[1] - p2[1])) ) ;
end;
$$;


ALTER FUNCTION gm.distancia_ponto_ponto(p1 point, p2 point) OWNER TO metroplan;

--
-- Name: distancia_ponto_segmento(point, point, point); Type: FUNCTION; Schema: gm; Owner: metroplan
--

CREATE FUNCTION gm.distancia_ponto_segmento(px point, pa point, pb point) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
declare 
A numeric; B numeric; C numeric; D numeric;
dot numeric; len_sq numeric; param numeric;
distancia numeric;
xx numeric; yy numeric;
begin

	A = px[0] - pa[0];
	B = px[1] - pa[1];
	C = pb[0] - pa[0];
	D = pb[1] - pa[1];
     
	dot = A * C + B * D;
	len_sq = C * C + D * D;
	param = dot / len_sq;

	if param < 0  then
		xx = x1;
		yy = y1;
	elsif param > 1  then
		xx = x2;
		yy = y2;
	else
		xx = x1 + param * C;
		yy = y1 + param * D;
	end if;
     
	distancia = gm.distancia_ponto_ponto(point(px, py), point(xx, yy));

	return distancia;
	
end;
$$;


ALTER FUNCTION gm.distancia_ponto_segmento(px point, pa point, pb point) OWNER TO metroplan;

--
-- Name: interseccao_ponto_linha(point, point, point); Type: FUNCTION; Schema: gm; Owner: metroplan
--

CREATE FUNCTION gm.interseccao_ponto_linha(px point, pa point, pb point) RETURNS point
    LANGUAGE plpgsql
    AS $$
declare
lefty numeric;
tg numeric;
x numeric; y numeric; x0 numeric; y0 numeric; x1 numeric; y1 numeric;
begin
	x = px[0];
	y = px[1];
	x0 = pa[0];
	y0 = pa[1];
	x1 = pb[0];
	y1 = pb[1];

	if x1 is null or x0 is null or (x1 - x0 = 0) then
		return point(x0, y);
	elseif y1 is null or y0 is null or (y1 - y0 = 0) then
		return point(x, y0);
	end if;
	tg = -1 / ((y1 - y0) / (x1 - x0));
	lefty = (x1 * (x * tg - y + y0) + x0 * (x * - tg + y - y1)) / (tg * (x1 - x0) + y0 - y1);
	return point(lefty, tg * lefty - tg * x + y);
end;
$$;


ALTER FUNCTION gm.interseccao_ponto_linha(px point, pa point, pb point) OWNER TO metroplan;

--
-- Name: interseccao_ponto_segmento(point, point, point); Type: FUNCTION; Schema: gm; Owner: metroplan
--

CREATE FUNCTION gm.interseccao_ponto_segmento(px point, pa point, pb point) RETURNS point
    LANGUAGE plpgsql
    AS $$
declare
d1 numeric; d2 numeric; d3 numeric;
inters_linha point;
begin


	inters_linha = gm.interseccao_ponto_linha(px, pa, pb);
	d1 = gm.distancia_ponto_ponto(px, inters_linha);
	d2 = gm.distancia_ponto_ponto(px, pa);
	d3 = gm.distancia_ponto_ponto(px, pb);

	/*raise notice '%', d1;
	raise notice '%', d2;
	raise notice '%', d3;*/
	

	if d1 < d2 and d1 < d3 then
		return inters_linha;
	elsif d2 < d1 and d2 < d3 then
		return pa;
	else
		return pb;
	end if;
	

end;
$$;


ALTER FUNCTION gm.interseccao_ponto_segmento(px point, pa point, pb point) OWNER TO metroplan;

--
-- Name: formata_auto(text); Type: FUNCTION; Schema: multas; Owner: metroplan
--

CREATE FUNCTION multas.formata_auto(codigo text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$

	--select substr($1, 1, 4) || '/' || substr($1, 5, 6)
	select substr(codigo, 1, length(codigo) - 2) || '/' || substr(codigo, length(codigo) - 1, length(codigo))

$_$;


ALTER FUNCTION multas.formata_auto(codigo text) OWNER TO metroplan;

--
-- Name: proximo_codigo_auto(); Type: FUNCTION; Schema: multas; Owner: metroplan
--

CREATE FUNCTION multas.proximo_codigo_auto() RETURNS text
    LANGUAGE plpgsql
    AS $_$
declare 
num text;
begin
	num = (select ((substring(codigo from 1 for length(codigo)-2))::int+1)::text from multas.auto 
		where codigo is not null and length(codigo) = 7 and codigo not like '99999%' and
		substring(codigo from '..$') = to_char(now(), 'yy')
		order by substring(codigo from 1 for length(codigo)-2) desc
		limit 1);

	if num is null then
		num := '1';
	end if;
	
	return lpad(num || to_char(now(), 'yy'), 7, '0');

end;
$_$;


ALTER FUNCTION multas.proximo_codigo_auto() OWNER TO metroplan;

--
-- Name: upper_auto(); Type: FUNCTION; Schema: multas; Owner: metroplan
--

CREATE FUNCTION multas.upper_auto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.observacoes = upper(trim(NEW.observacoes));
	NEW.descricao = upper(trim(NEW.descricao));
	NEW.endereco_infracao = upper(trim(NEW.endereco_infracao));
	NEW.decreto = upper(trim(NEW.decreto));

	return NEW;
END;$$;


ALTER FUNCTION multas.upper_auto() OWNER TO metroplan;

--
-- Name: upper_fiscal(); Type: FUNCTION; Schema: multas; Owner: metroplan
--

CREATE FUNCTION multas.upper_fiscal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.nome = upper(trim(NEW.nome));
	return NEW;
END;$$;


ALTER FUNCTION multas.upper_fiscal() OWNER TO metroplan;

--
-- Name: carrega_logs(date); Type: FUNCTION; Schema: postgres; Owner: metroplan
--

CREATE FUNCTION postgres.carrega_logs(data date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE filename TEXT;
BEGIN
SET client_encoding = 'WIN1252';
CREATE TEMPORARY TABLE temp_log
(
  log_time timestamp(3) with time zone,
  user_name text,
  database_name text,
  process_id integer,
  connection_from text,
  session_id text,
  session_line_num bigint,
  command_tag text,
  session_start_time timestamp with time zone,
  virtual_transaction_id text,
  transaction_id bigint,
  error_severity text,
  sql_state_code text,
  message text,
  detail text,
  hint text,
  internal_query text,
  internal_query_pos integer,
  context text,
  query text,
  query_pos integer,
  location text,
  PRIMARY KEY (session_id, session_line_num)
);
filename := E'C:/Arquivos de programas/PostgreSQL/8.4/data/pg_log/postgresql-' || to_char(data, 'YYYY-MM-DD') || '.csv';
EXECUTE 'COPY temp_log FROM ''' || filename || ''' WITH csv;';
INSERT INTO postgres.postgres_log SELECT * FROM temp_log WHERE (session_id, session_line_num) NOT IN (SELECT session_id, session_line_num FROM postgres.postgres_log);
DROP TABLE temp_log;
END;
$$;


ALTER FUNCTION postgres.carrega_logs(data date) OWNER TO metroplan;

--
-- Name: checa_empresa_admin(); Type: FUNCTION; Schema: postgres; Owner: postgres
--

CREATE FUNCTION postgres.checa_empresa_admin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- Count existing admins for this empresa
        IF NOT EXISTS (SELECT 1 FROM web.usuario WHERE empresa_cnpj = NEW.empresa_cnpj AND eh_empresa = TRUE) THEN
            IF NEW.eh_empresa IS NOT TRUE THEN
                RAISE EXCEPTION 'Ao menos um usuário precisa ser a empresa.';
            END IF;
        END IF;
    ELSIF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
        -- After the operation, ensure at least one TRUE remains
        IF NOT EXISTS (SELECT 1 FROM web.usuario WHERE empresa_cnpj = COALESCE(NEW.empresa_cnpj, OLD.empresa_cnpj) AND eh_empresa = TRUE) THEN
            RAISE EXCEPTION 'Ao menos um usuário precisa ser a empresa.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION postgres.checa_empresa_admin() OWNER TO postgres;

--
-- Name: conta_contrato_vencido(text, date); Type: FUNCTION; Schema: public; Owner: metroplan
--

CREATE FUNCTION public.conta_contrato_vencido(regiao text, data date) RETURNS integer
    LANGUAGE sql STABLE
    AS $_$


select count(distinct placa)::integer from fretamento.raiz
where
-- autorizacao.veiculo_placa = veiculo.placa and veiculo.empresa_cnpj = empresa.cnpj and 
data_exclusao_fretamento is null
and regiao_codigo = $1
and (validade_contrato) < data
and (
(validade_seguro >= data
			or validade_autorizacao >= data
			or validade_laudo >= data)
)
and fretamento.pertence(placa, regiao) = true

$_$;


ALTER FUNCTION public.conta_contrato_vencido(regiao text, data date) OWNER TO metroplan;

--
-- Name: gera_codigo_autorizacao(); Type: FUNCTION; Schema: public; Owner: metroplan
--

CREATE FUNCTION public.gera_codigo_autorizacao() RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
num text;
counter integer;
teste text;
resultado text;
begin

	lock table eventual.autorizacao, eventual.codigos_usados;
	num := (select codigo::integer from eventual.autorizacao 
		order by codigo::integer desc limit 1);

	if num is null then
		num := '1';
	end if;

	num := ((num::int)+1)::text;
	
	insert into eventual.codigos_usados (codigo) values(num);

	return num;

end;
$$;


ALTER FUNCTION public.gera_codigo_autorizacao() OWNER TO metroplan;

--
-- Name: nome_empresa_por_placa(text); Type: FUNCTION; Schema: public; Owner: metroplan
--

CREATE FUNCTION public.nome_empresa_por_placa(placa text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
	select nome from geral.empresa, geral.veiculo where veiculo.placa = $1 and veiculo.empresa_cnpj = empresa.cnpj
$_$;


ALTER FUNCTION public.nome_empresa_por_placa(placa text) OWNER TO metroplan;

--
-- Name: percentual_reclamacoes_por_empresa(date, date); Type: FUNCTION; Schema: saac; Owner: metroplan
--

CREATE FUNCTION saac.percentual_reclamacoes_por_empresa(date, date) RETURNS TABLE(codigo text, nome text, numero text, percentual text)
    LANGUAGE sql
    AS $_$

--TODO: usar between.
SELECT ocorrencia.empresa_codigo, empresa.nome, count(*)::text AS numero, (count(*) * 100 / (( SELECT count(*) AS count
           FROM   saac.ocorrencia
          WHERE ocorrencia.ocorrencia_tipo_nome::text = 'Reclamação'::text 
          and date_trunc('day', ocorrencia.data_atendimento) >= date_trunc('day', $1 )
          and date_trunc('day', ocorrencia.data_atendimento) <= date_trunc('day', $2))))::text AS percentual 
   FROM saac.ocorrencia, geral.empresa_codigo, geral.empresa
   WHERE ocorrencia.ocorrencia_tipo_nome::text = 'Reclamação'::text 
	and date_trunc('day', ocorrencia.data_atendimento) >= date_trunc('day', $1)
	and date_trunc('day', ocorrencia.data_atendimento) <= date_trunc('day', $2)
	and ocorrencia.empresa_codigo = empresa_codigo.codigo 
	AND empresa_codigo.empresa_cnpj = empresa.cnpj
  GROUP BY ocorrencia.empresa_codigo, empresa.nome, ocorrencia.ocorrencia_tipo_nome
  ORDER BY count(*) * 100 / (( SELECT count(*) AS count
           FROM saac.ocorrencia
          WHERE ocorrencia.ocorrencia_tipo_nome::text = 'Reclamação'::text 
          and date_trunc('day', ocorrencia.data_atendimento) >= date_trunc('day', $1)
          and date_trunc('day', ocorrencia.data_atendimento) <= date_trunc('day', $2))), ocorrencia.empresa_codigo;


$_$;


ALTER FUNCTION saac.percentual_reclamacoes_por_empresa(date, date) OWNER TO metroplan;

--
-- Name: tg_seta_data_atendimento(); Type: FUNCTION; Schema: saac; Owner: metroplan
--

CREATE FUNCTION saac.tg_seta_data_atendimento() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	NEW.data_atendimento = now();
	return NEW;
END;$$;


ALTER FUNCTION saac.tg_seta_data_atendimento() OWNER TO metroplan;

--
-- Name: upper_ocorrencia(); Type: FUNCTION; Schema: saac; Owner: metroplan
--

CREATE FUNCTION saac.upper_ocorrencia() RETURNS trigger
    LANGUAGE plpgsql
    AS $$BEGIN
	--NEW.local_ocorrencia = upper(trim(NEW.local_ocorrencia));
	--NEW.nome_reclamante = upper(trim(NEW.nome_reclamante));
	--NEW.descricao = upper(trim(NEW.descricao));
	return NEW;
END;$$;


ALTER FUNCTION saac.upper_ocorrencia() OWNER TO metroplan;

--
-- Name: normalizar_email_usuario(); Type: FUNCTION; Schema: web; Owner: postgres
--

CREATE FUNCTION web.normalizar_email_usuario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.email IS NOT NULL THEN
        -- Normalize: lowercase, trim, and keep only a-z, 0-9, ., _, -, +
--        NEW.email := lower(
--            regexp_replace(
--                btrim(NEW.email),
--                '[^a-z0-9._+-]',
--                '',
--                'g'
--            )
--        );
		NEW.email := lower(NEW.email);
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION web.normalizar_email_usuario() OWNER TO postgres;

--
-- Name: log; Type: TABLE; Schema: admin; Owner: metroplan
--

CREATE TABLE admin.log (
    id integer NOT NULL,
    data timestamp without time zone,
    usuario_nome text,
    sucesso boolean,
    ip_remoto inet,
    ip_local inet,
    usuario_os text,
    hostname text
);


ALTER TABLE admin.log OWNER TO metroplan;

--
-- Name: COLUMN log.ip_remoto; Type: COMMENT; Schema: admin; Owner: metroplan
--

COMMENT ON COLUMN admin.log.ip_remoto IS 'resultado de inet_client_addr()';


--
-- Name: COLUMN log.ip_local; Type: COMMENT; Schema: admin; Owner: metroplan
--

COMMENT ON COLUMN admin.log.ip_local IS 'user supplied
''local'' do ponto de vista do usuário, numa LAN talvez seja igual ao remoto';


--
-- Name: COLUMN log.usuario_os; Type: COMMENT; Schema: admin; Owner: metroplan
--

COMMENT ON COLUMN admin.log.usuario_os IS 'user supplied';


--
-- Name: COLUMN log.hostname; Type: COMMENT; Schema: admin; Owner: metroplan
--

COMMENT ON COLUMN admin.log.hostname IS 'user supplied';


--
-- Name: log_id_seq; Type: SEQUENCE; Schema: admin; Owner: metroplan
--

CREATE SEQUENCE admin.log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE admin.log_id_seq OWNER TO metroplan;

--
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: admin; Owner: metroplan
--

ALTER SEQUENCE admin.log_id_seq OWNED BY admin.log.id;


--
-- Name: permissao; Type: TABLE; Schema: admin; Owner: metroplan
--

CREATE TABLE admin.permissao (
    nome text NOT NULL
);


ALTER TABLE admin.permissao OWNER TO metroplan;

--
-- Name: usuario; Type: TABLE; Schema: admin; Owner: metroplan
--

CREATE TABLE admin.usuario (
    nome text NOT NULL,
    senha text NOT NULL,
    bloqueado boolean DEFAULT false NOT NULL
);


ALTER TABLE admin.usuario OWNER TO metroplan;

--
-- Name: usuario_permissao; Type: TABLE; Schema: admin; Owner: metroplan
--

CREATE TABLE admin.usuario_permissao (
    permissao_id integer NOT NULL,
    permissao_nome text NOT NULL,
    usuario_nome text NOT NULL,
    leitura boolean DEFAULT true NOT NULL,
    escrita boolean DEFAULT false NOT NULL
);


ALTER TABLE admin.usuario_permissao OWNER TO metroplan;

--
-- Name: usuario_permissao_permissao_id_seq; Type: SEQUENCE; Schema: admin; Owner: metroplan
--

CREATE SEQUENCE admin.usuario_permissao_permissao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE admin.usuario_permissao_permissao_id_seq OWNER TO metroplan;

--
-- Name: usuario_permissao_permissao_id_seq; Type: SEQUENCE OWNED BY; Schema: admin; Owner: metroplan
--

ALTER SEQUENCE admin.usuario_permissao_permissao_id_seq OWNED BY admin.usuario_permissao.permissao_id;


--
-- Name: versao; Type: TABLE; Schema: admin; Owner: metroplan
--

CREATE TABLE admin.versao (
    major integer NOT NULL,
    minor integer NOT NULL,
    revision integer NOT NULL,
    data timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE admin.versao OWNER TO metroplan;

--
-- Name: denuncia; Type: TABLE; Schema: app; Owner: metroplan
--

CREATE TABLE app.denuncia (
    id integer NOT NULL,
    token text,
    local text,
    ip inet,
    data timestamp with time zone DEFAULT now() NOT NULL,
    automatico boolean DEFAULT false NOT NULL
);


ALTER TABLE app.denuncia OWNER TO metroplan;

--
-- Name: denuncia_id_seq; Type: SEQUENCE; Schema: app; Owner: metroplan
--

CREATE SEQUENCE app.denuncia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE app.denuncia_id_seq OWNER TO metroplan;

--
-- Name: denuncia_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: metroplan
--

ALTER SEQUENCE app.denuncia_id_seq OWNED BY app.denuncia.id;


--
-- Name: log_acesso; Type: TABLE; Schema: app; Owner: metroplan
--

CREATE TABLE app.log_acesso (
    id integer NOT NULL,
    usuario text,
    placa text,
    data timestamp without time zone DEFAULT now()
);


ALTER TABLE app.log_acesso OWNER TO metroplan;

--
-- Name: log_acesso_id_seq; Type: SEQUENCE; Schema: app; Owner: metroplan
--

CREATE SEQUENCE app.log_acesso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE app.log_acesso_id_seq OWNER TO metroplan;

--
-- Name: log_acesso_id_seq; Type: SEQUENCE OWNED BY; Schema: app; Owner: metroplan
--

ALTER SEQUENCE app.log_acesso_id_seq OWNED BY app.log_acesso.id;


--
-- Name: log_http; Type: TABLE; Schema: app; Owner: postgres
--

CREATE TABLE app.log_http (
    id integer NOT NULL,
    url text,
    user_agent text,
    ip inet,
    headers text,
    environ text,
    data timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE app.log_http OWNER TO postgres;

--
-- Name: log_http_id_seq; Type: SEQUENCE; Schema: app; Owner: metroplan
--

CREATE SEQUENCE app.log_http_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE app.log_http_id_seq OWNER TO metroplan;

--
-- Name: log_http_id_seq1; Type: SEQUENCE; Schema: app; Owner: postgres
--

CREATE SEQUENCE app.log_http_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE app.log_http_id_seq1 OWNER TO postgres;

--
-- Name: log_http_id_seq1; Type: SEQUENCE OWNED BY; Schema: app; Owner: postgres
--

ALTER SEQUENCE app.log_http_id_seq1 OWNED BY app.log_http.id;


--
-- Name: empresa; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.empresa (
    cnpj text NOT NULL,
    nome text NOT NULL,
    telefone character varying,
    fax character varying,
    cep text,
    email text,
    regiao_codigo text,
    processo text,
    endereco character varying,
    municipio_nome text,
    nome_simplificado text,
    data_inicio_operacao date,
    data_fim_operacao date,
    inscricao_estadual text,
    garagem_telefone character varying,
    garagem_cep character varying,
    observacoes text,
    data_inclusao_metroplan date,
    garagem_endereco character varying,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    telefone2 text,
    procurador text,
    procurador_endereco text,
    procurador_telefone text,
    procurador_email text,
    data_entrega_documentacao date,
    eh_acordo boolean DEFAULT false NOT NULL,
    nome_fantasia text,
    endereco_numero text,
    endereco_complemento text,
    bairro text,
    cidade text,
    estado text,
    celular text,
    data_inclusao_eventual date,
    eventual_status text,
    CONSTRAINT empresa_fax_valido_chk CHECK (((fax IS NULL) OR ((fax)::text ~ '^[0-9]{10}$'::text)))
);


ALTER TABLE geral.empresa OWNER TO metroplan;

--
-- Name: TABLE empresa; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON TABLE geral.empresa IS 'TODO
apos migracao:
	* checar not-null das regioes.';


--
-- Name: COLUMN empresa.regiao_codigo; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.regiao_codigo IS 'fretamento';


--
-- Name: COLUMN empresa.processo; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.processo IS 'fretamento';


--
-- Name: COLUMN empresa.municipio_nome; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.municipio_nome IS 'fretamento';


--
-- Name: COLUMN empresa.nome_simplificado; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.nome_simplificado IS 'concessao';


--
-- Name: COLUMN empresa.data_inicio_operacao; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.data_inicio_operacao IS 'concessao';


--
-- Name: COLUMN empresa.data_fim_operacao; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.data_fim_operacao IS 'concessao';


--
-- Name: COLUMN empresa.garagem_telefone; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.garagem_telefone IS 'concessao';


--
-- Name: COLUMN empresa.garagem_cep; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.garagem_cep IS 'concessao';


--
-- Name: COLUMN empresa.observacoes; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.observacoes IS 'concessao';


--
-- Name: COLUMN empresa.data_inclusao_metroplan; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.data_inclusao_metroplan IS 'concessao';


--
-- Name: COLUMN empresa.garagem_endereco; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.empresa.garagem_endereco IS 'concessao';


--
-- Name: empresa_codigo; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.empresa_codigo (
    codigo text NOT NULL,
    empresa_cnpj text NOT NULL,
    regiao_codigo text NOT NULL
);


ALTER TABLE geral.empresa_codigo OWNER TO metroplan;

--
-- Name: veiculo; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo (
    placa text NOT NULL,
    prefixo integer,
    renavan text,
    potencia_motor integer,
    numero_portas integer,
    tem_ar_condicionado boolean,
    tem_poltrona_reclinavel boolean,
    chassi_ano integer,
    carroceria_ano integer,
    veiculo_qualidade_nome text,
    veiculo_motor_nome text,
    chassi_numero text,
    empresa_codigo_codigo text,
    veiculo_chassi_nome text,
    veiculo_carroceria_nome text,
    acordo_codigo text,
    cor_principal_nome text,
    cor_secundaria_nome text,
    veiculo_combustivel_nome text,
    tem_assento_cobrador boolean,
    tem_catraca boolean,
    numero_lugares integer,
    empresa_cnpj text,
    ano_fabricacao integer,
    modelo text,
    ativo boolean,
    data_inclusao_concessao date,
    data_exclusao_concessao date,
    veiculo_rodados_nome text,
    tem_elevador boolean,
    numero_inclusao text,
    numero_exclusao text,
    validador_be_numero text,
    observacoes text,
    processo_exclusao text,
    processo_inclusao text,
    classificacao_inmetro_nome text,
    data_inclusao_fretamento date,
    data_exclusao_fretamento date,
    data_inicio_seguro date,
    data_vencimento_seguro date,
    concessao_veiculo_tipo_nome text,
    fretamento_veiculo_tipo_nome text,
    comodato boolean DEFAULT false,
    apolice text,
    seguradora text,
    crlv integer,
    inativo boolean DEFAULT false NOT NULL,
    modelo_ano integer,
    data_inclusao_eventual date,
    eventual_status text,
    CONSTRAINT codigo_ou_cnpj CHECK (((empresa_codigo_codigo IS NOT NULL) OR (empresa_cnpj IS NOT NULL))),
    CONSTRAINT placa_valida_chk CHECK ((placa ~ '[A-Z]{3}[0-9]([A-Z0-9])[0-9][0-9]'::text))
);


ALTER TABLE geral.veiculo OWNER TO metroplan;

--
-- Name: COLUMN veiculo.ano_fabricacao; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo.ano_fabricacao IS 'fretamento';


--
-- Name: COLUMN veiculo.modelo; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo.modelo IS 'fretamento';


--
-- Name: COLUMN veiculo.ativo; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo.ativo IS 'fretamento
tem q ser substituido por data_exclusao';


--
-- Name: COLUMN veiculo.numero_inclusao; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo.numero_inclusao IS 'TODO: normalizar a fonte e setar unique';


--
-- Name: COLUMN veiculo.inativo; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo.inativo IS 'fretamento 04/2021';


--
-- Name: ar_condicionado_soma; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.ar_condicionado_soma AS
 SELECT empresa_codigo.regiao_codigo,
    empresa.nome AS empresa_nome,
    COALESCE(veiculo.acordo_codigo, veiculo.empresa_codigo_codigo) AS empresa_codigo_codigo,
    count(*) FILTER (WHERE (veiculo.classificacao_inmetro_nome = ANY (ARRAY['RODOVIÁRIO'::text, 'SELETIVO'::text]))) AS rodoviario_total,
    count(*) FILTER (WHERE ((veiculo.classificacao_inmetro_nome = ANY (ARRAY['RODOVIÁRIO'::text, 'SELETIVO'::text])) AND (veiculo.tem_ar_condicionado = true))) AS rodoviario_com_ac,
    count(*) FILTER (WHERE (veiculo.classificacao_inmetro_nome = 'URBANO'::text)) AS urbano_total,
    count(*) FILTER (WHERE ((veiculo.classificacao_inmetro_nome = 'URBANO'::text) AND (veiculo.tem_ar_condicionado = true))) AS urbano_com_ac,
    count(*) FILTER (WHERE (veiculo.tem_ar_condicionado = true)) AS total_com_ac
   FROM ((geral.veiculo
     JOIN geral.empresa_codigo ON ((COALESCE(veiculo.acordo_codigo, veiculo.empresa_codigo_codigo) = empresa_codigo.codigo)))
     JOIN geral.empresa ON ((empresa_codigo.empresa_cnpj = empresa.cnpj)))
  WHERE ((veiculo.data_inclusao_concessao IS NOT NULL) AND ((veiculo.data_exclusao_concessao IS NULL) OR (veiculo.data_exclusao_concessao > ('now'::text)::date)))
  GROUP BY empresa_codigo.regiao_codigo, empresa.nome, COALESCE(veiculo.acordo_codigo, veiculo.empresa_codigo_codigo)
  ORDER BY empresa_codigo.regiao_codigo, COALESCE(veiculo.acordo_codigo, veiculo.empresa_codigo_codigo);


ALTER TABLE concessao.ar_condicionado_soma OWNER TO metroplan;

--
-- Name: bod_bod_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.bod_bod_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.bod_bod_id_seq OWNER TO metroplan;

--
-- Name: bod; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.bod (
    bod_id bigint DEFAULT nextval('concessao.bod_bod_id_seq'::regclass) NOT NULL,
    ano integer,
    mes integer,
    empresa_codigo text,
    linha_codigo text,
    ramal integer,
    linha_nome text,
    servico text,
    ida integer,
    extensao_a numeric(6,2) DEFAULT NULL::numeric,
    extensao_b numeric(6,2) DEFAULT NULL::numeric,
    tarifa_comum numeric(4,2),
    tarifa_escolar numeric(4,2),
    lotacao_media numeric(6,2),
    extensao_percorrida_simples numeric(10,2),
    extensao_percorrida_expressa numeric(10,2),
    extensao_percorrida_deslocamento numeric(10,2),
    viagens_simples integer,
    viagens_expressas integer,
    viagens_deslocamentos integer,
    passageiros_comum integer,
    passageiros_escolar integer,
    passageiros_passe_livre integer,
    passageiros_isentos integer,
    passageiros_integracao_rodoviaria integer,
    passageiros_integracao_ferroviaria integer,
    receita_comum numeric(12,2),
    receita_escolar numeric(12,2),
    receita_passe_livre numeric(12,2),
    frota_operante integer
);


ALTER TABLE concessao.bod OWNER TO metroplan;

--
-- Name: bod_arquivo_bod_arquivo_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.bod_arquivo_bod_arquivo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.bod_arquivo_bod_arquivo_id_seq OWNER TO metroplan;

--
-- Name: bod_arquivo; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.bod_arquivo (
    bod_arquivo_id bigint DEFAULT nextval('concessao.bod_arquivo_bod_arquivo_id_seq'::regclass) NOT NULL,
    data_upload timestamp without time zone DEFAULT now(),
    mes integer NOT NULL,
    ano integer NOT NULL,
    empresa_codigo text NOT NULL,
    arquivo bytea NOT NULL
);


ALTER TABLE concessao.bod_arquivo OWNER TO metroplan;

--
-- Name: bod_consolidado_setm; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.bod_consolidado_setm AS
 WITH dados AS (
         SELECT bod.ano,
            empresa_codigo.regiao_codigo,
            concessao.bod_soma_passageiros_regiao(1, bod.ano, empresa_codigo.regiao_codigo) AS janeiro,
            concessao.bod_soma_passageiros_regiao(2, bod.ano, empresa_codigo.regiao_codigo) AS fevereiro,
            concessao.bod_soma_passageiros_regiao(3, bod.ano, empresa_codigo.regiao_codigo) AS marco,
            concessao.bod_soma_passageiros_regiao(4, bod.ano, empresa_codigo.regiao_codigo) AS abril,
            concessao.bod_soma_passageiros_regiao(5, bod.ano, empresa_codigo.regiao_codigo) AS maio,
            concessao.bod_soma_passageiros_regiao(6, bod.ano, empresa_codigo.regiao_codigo) AS junho,
            concessao.bod_soma_passageiros_regiao(7, bod.ano, empresa_codigo.regiao_codigo) AS julho,
            concessao.bod_soma_passageiros_regiao(8, bod.ano, empresa_codigo.regiao_codigo) AS agosto,
            concessao.bod_soma_passageiros_regiao(9, bod.ano, empresa_codigo.regiao_codigo) AS setembro,
            concessao.bod_soma_passageiros_regiao(10, bod.ano, empresa_codigo.regiao_codigo) AS outubro,
            concessao.bod_soma_passageiros_regiao(11, bod.ano, empresa_codigo.regiao_codigo) AS novembro,
            concessao.bod_soma_passageiros_regiao(12, bod.ano, empresa_codigo.regiao_codigo) AS dezembro,
            (((((((((((concessao.bod_soma_passageiros_regiao(1, bod.ano, empresa_codigo.regiao_codigo) + concessao.bod_soma_passageiros_regiao(2, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(3, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(4, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(5, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(6, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(7, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(8, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(9, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(10, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(11, bod.ano, empresa_codigo.regiao_codigo)) + concessao.bod_soma_passageiros_regiao(12, bod.ano, empresa_codigo.regiao_codigo)) AS total
           FROM (concessao.bod
             JOIN geral.empresa_codigo ON ((bod.empresa_codigo = empresa_codigo.codigo)))
          GROUP BY bod.ano, empresa_codigo.regiao_codigo
        )
 SELECT dados.ano,
    dados.regiao_codigo,
    dados.janeiro,
    dados.fevereiro,
    dados.marco,
    dados.abril,
    dados.maio,
    dados.junho,
    dados.julho,
    dados.agosto,
    dados.setembro,
    dados.outubro,
    dados.novembro,
    dados.dezembro,
    dados.total,
    (((dados.total)::numeric * 100.0) / (sum(dados.total) OVER (PARTITION BY dados.ano))::numeric) AS porcentagem
   FROM dados
  ORDER BY dados.ano, dados.regiao_codigo;


ALTER TABLE concessao.bod_consolidado_setm OWNER TO metroplan;

--
-- Name: linha; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.linha (
    codigo text NOT NULL,
    nome text,
    via text,
    tarifa numeric(12,2),
    restricoes character varying,
    observacoes character varying,
    codigo_daer text,
    linha_servico_nome text,
    linha_modalidade_nome text,
    migra_contrato character varying,
    linha_caracteristica_nome text,
    eixo_nome text,
    municipio_nome_origem text,
    municipio_nome_destino text,
    migra_contrato_aditivo character varying,
    extensao_1a numeric(7,2),
    extensao_1b numeric(7,2),
    extensao_2a numeric(7,2),
    extensao_2b numeric(7,2),
    extensao_3a numeric(7,2),
    extensao_3b numeric(7,2),
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    tempo_viagem_1 integer,
    tempo_viagem_2 integer,
    tempo_viagem_3 integer,
    empresa_codigo_codigo text NOT NULL,
    terminal_ida text,
    terminal_volta text,
    veiculo_qualidade_nome text,
    circular boolean DEFAULT false,
    linha_codigo_principal text,
    via_acesso boolean DEFAULT false NOT NULL,
    id integer NOT NULL
);


ALTER TABLE concessao.linha OWNER TO metroplan;

--
-- Name: COLUMN linha.tempo_viagem_1; Type: COMMENT; Schema: concessao; Owner: metroplan
--

COMMENT ON COLUMN concessao.linha.tempo_viagem_1 IS 'Tempo de viagem em minutos';


--
-- Name: COLUMN linha.tempo_viagem_2; Type: COMMENT; Schema: concessao; Owner: metroplan
--

COMMENT ON COLUMN concessao.linha.tempo_viagem_2 IS 'Tempo de viagem em minutos';


--
-- Name: linha_historico; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.linha_historico (
    id integer NOT NULL,
    linha_id integer,
    linha_codigo text,
    data_historico_inicio date,
    data_historico_fim date,
    linha_nome text,
    empresa_codigo text,
    empresa_nome text,
    via text,
    linha_modalidade_nome text,
    terminal_ida text,
    terminal_volta text,
    extensao_1a numeric(7,2),
    extensao_1b numeric(7,2),
    extensao_2a numeric(7,2),
    extensao_2b numeric(7,2),
    extensao_3a numeric(7,2),
    extensao_3b numeric(7,2),
    tempo_viagem_1 integer,
    tempo_viagem_2 integer,
    tempo_viagem_3 integer,
    linha_situacao_nome text,
    municipio_nome_origem text,
    municipio_nome_destino text,
    ordem_servico_numero text,
    os_crua text,
    data_emissao date,
    data_vigencia date,
    data_validade date,
    data_inclusao date,
    data_exclusao date,
    restricoes text,
    observacoes text,
    circular boolean,
    tarifa numeric,
    data_inicio_corrigida date
);


ALTER TABLE concessao.linha_historico OWNER TO metroplan;

--
-- Name: ordem_servico; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.ordem_servico (
    numero text DEFAULT concessao.proxima_ordem_servico() NOT NULL,
    processo text,
    data_emissao date,
    data_vigencia date,
    ata_cetm text,
    ordem_servico_assunto_descricao text,
    CONSTRAINT ata_cetm_length_chk CHECK ((length(ata_cetm) = 6)),
    CONSTRAINT numero_length_chk CHECK ((length(numero) = 6)),
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE concessao.ordem_servico OWNER TO metroplan;

--
-- Name: ordem_servico__linha; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.ordem_servico__linha (
    ordem_servico__linha_id integer NOT NULL,
    ordem_servico_numero text NOT NULL,
    linha_codigo text NOT NULL,
    data_validade date
);


ALTER TABLE concessao.ordem_servico__linha OWNER TO metroplan;

--
-- Name: cabecalho_rel_horario_itinerario; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.cabecalho_rel_horario_itinerario AS
 SELECT lh.data_historico_inicio,
    lh.data_historico_fim,
    lh.id,
    lh.linha_id,
    lh.linha_codigo,
    lh.linha_nome,
    lh.empresa_codigo,
    lh.empresa_nome,
    lh.via,
    lh.linha_modalidade_nome,
    COALESCE(lh.terminal_ida, ''::text) AS terminal_ida,
    COALESCE(lh.terminal_volta, ''::text) AS terminal_volta,
    to_char((COALESCE(lh.extensao_1a, COALESCE(lh.extensao_3a, (0)::numeric)) + COALESCE(lh.extensao_1b, COALESCE(lh.extensao_3b, (0)::numeric))), 'FM999990D00'::text) AS extensao_1,
    to_char((COALESCE(lh.extensao_2a, (0)::numeric) + COALESCE(lh.extensao_2b, (0)::numeric)), 'FM999990D00'::text) AS extensao_2,
    COALESCE(lh.tempo_viagem_1, COALESCE(lh.tempo_viagem_3, 0)) AS tempo_viagem_1,
    COALESCE(lh.tempo_viagem_2, 0) AS tempo_viagem_2,
    lh.linha_situacao_nome,
    lh.municipio_nome_origem,
    lh.municipio_nome_destino,
    concessao.formata_os(osl.ordem_servico_numero) AS ordem_servico_numero,
    osl.ordem_servico_numero AS os_crua,
    to_char((osl.data_emissao)::timestamp with time zone, 'DD/MM/YYYY'::text) AS data_emissao,
    to_char((osl.data_vigencia)::timestamp with time zone, 'DD/MM/YYYY'::text) AS data_vigencia,
    to_char((osl.data_validade)::timestamp with time zone, 'DD/MM/YYYY'::text) AS data_validade,
    lh.data_inclusao,
    lh.data_exclusao,
    lh.restricoes,
    lh.observacoes,
    lh.circular,
    lh.tarifa,
    geral.formata_dinheiro(lh.tarifa) AS starifa
   FROM ((concessao.linha_historico lh
     JOIN concessao.linha l ON ((lh.linha_id = l.id)))
     LEFT JOIN LATERAL ( SELECT os_linha.ordem_servico_numero,
            os_linha.data_validade,
            os.data_emissao,
            os.data_vigencia
           FROM (concessao.ordem_servico__linha os_linha
             JOIN concessao.ordem_servico os ON ((os.numero = os_linha.ordem_servico_numero)))
          WHERE ((os_linha.linha_codigo = lh.linha_codigo) AND (os.data_vigencia <= COALESCE(lh.data_historico_fim, 'infinity'::date)) AND (COALESCE(os_linha.data_validade, 'infinity'::date) >= lh.data_historico_inicio))
          ORDER BY os.data_vigencia DESC
         LIMIT 1) osl ON (true));


ALTER TABLE concessao.cabecalho_rel_horario_itinerario OWNER TO metroplan;

--
-- Name: empresa_codigo_hidroviario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.empresa_codigo_hidroviario (
    codigo text NOT NULL,
    empresa_hidroviario_cnpj text NOT NULL,
    regiao_codigo text NOT NULL
);


ALTER TABLE concessao.empresa_codigo_hidroviario OWNER TO metroplan;

--
-- Name: empresa_hidroviario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.empresa_hidroviario (
    cnpj text NOT NULL,
    nome text NOT NULL,
    recefitur integer,
    telefone character varying,
    fax character varying,
    cep text,
    email text,
    nome_simplificado text,
    data_inicio_operacao date,
    data_fim_operacao date,
    inscricao_estadual text,
    garagem_telefone character varying,
    garagem_cep character varying,
    observacoes text,
    data_inclusao_metroplan date,
    garagem_endereco character varying,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    telefone2 text,
    procurador text,
    procurador_endereco text,
    procurador_telefone text,
    procurador_email text,
    endereco text,
    CONSTRAINT empresa_hidroviario_fax_valido_chk CHECK (((fax IS NULL) OR ((fax)::text ~ '^[0-9]{10}$'::text))),
    CONSTRAINT empresa_hidroviario_telefone_valido_chk CHECK ((((telefone IS NULL) OR ((telefone)::text ~ '^[0-9]{10}$'::text)) AND ((telefone2 IS NULL) OR (telefone2 ~ '^[0-9]{10}$'::text)) AND ((procurador_telefone IS NULL) OR (procurador_telefone ~ '^[0-9]{10}$'::text))))
);


ALTER TABLE concessao.empresa_hidroviario OWNER TO metroplan;

--
-- Name: linha_hidroviario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.linha_hidroviario (
    codigo text NOT NULL,
    nome text,
    via text,
    tarifa numeric(12,2),
    restricoes character varying,
    observacoes character varying,
    linha_servico_nome text,
    linha_modalidade_nome text,
    migra_contrato character varying,
    linha_caracteristica_nome text,
    eixo_nome text,
    municipio_nome_origem text,
    municipio_nome_destino text,
    migra_contrato_aditivo character varying,
    extensao_1 numeric(7,2),
    extensao_2 numeric(7,2),
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    tempo_viagem_1 integer,
    tempo_viagem_2 integer,
    empresa_codigo_hidroviario_codigo text NOT NULL,
    terminal_ida text,
    terminal_volta text,
    linha_codigo_principal text,
    tipo_embarcacao_nome text
);


ALTER TABLE concessao.linha_hidroviario OWNER TO metroplan;

--
-- Name: ordem_servico_hidroviario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.ordem_servico_hidroviario (
    numero text DEFAULT concessao.proxima_ordem_servico_hidroviario() NOT NULL,
    processo text,
    data_emissao date,
    data_vigencia date,
    ata_cetm text,
    ordem_servico_assunto_descricao text,
    CONSTRAINT ata_cetm_length_chk CHECK ((length(ata_cetm) = 6)),
    CONSTRAINT numero_length_chk CHECK ((length(numero) = 6)),
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE concessao.ordem_servico_hidroviario OWNER TO metroplan;

--
-- Name: ordem_servico_hidroviario__linha_hidroviario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.ordem_servico_hidroviario__linha_hidroviario (
    ordem_servico_hidroviario__linha_hidroviario_id integer NOT NULL,
    ordem_servico_hidroviario_numero text NOT NULL,
    linha_hidroviario_codigo text NOT NULL,
    data_validade date
);


ALTER TABLE concessao.ordem_servico_hidroviario__linha_hidroviario OWNER TO metroplan;

--
-- Name: cabecalho_rel_horario_itinerario_hidroviario_site; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.cabecalho_rel_horario_itinerario_hidroviario_site AS
 SELECT linha_hidroviario.codigo AS linha_codigo,
    linha_hidroviario.nome AS linha_nome,
    empresa_codigo_hidroviario.codigo AS empresa_codigo,
    empresa_hidroviario.nome AS empresa_nome,
    linha_hidroviario.via,
    linha_hidroviario.linha_modalidade_nome,
    linha_hidroviario.terminal_ida,
    linha_hidroviario.terminal_volta,
    to_char(COALESCE(linha_hidroviario.extensao_1, (0)::numeric), 'FM999990D00'::text) AS extensao_ida,
    to_char(COALESCE(linha_hidroviario.extensao_2, (0)::numeric), 'FM999990D00'::text) AS extensao_volta,
    COALESCE(linha_hidroviario.tempo_viagem_1, 0) AS tempo_viagem_ida,
    COALESCE(linha_hidroviario.tempo_viagem_2, 0) AS tempo_viagem_volta,
        CASE
            WHEN ((linha_hidroviario.data_exclusao IS NULL) OR (linha_hidroviario.data_exclusao > now())) THEN 'LINHA EM OPERAÇÃO'::text
            ELSE 'LINHA SUSPENSA'::text
        END AS linha_situacao_nome,
    linha_hidroviario.municipio_nome_origem,
    linha_hidroviario.municipio_nome_destino,
    linha_hidroviario.data_inclusao,
    linha_hidroviario.data_exclusao,
    linha_hidroviario.restricoes,
    linha_hidroviario.observacoes,
    false AS circular
   FROM ((((concessao.empresa_hidroviario
     JOIN concessao.empresa_codigo_hidroviario ON ((empresa_codigo_hidroviario.empresa_hidroviario_cnpj = empresa_hidroviario.cnpj)))
     JOIN concessao.linha_hidroviario ON ((linha_hidroviario.empresa_codigo_hidroviario_codigo = empresa_codigo_hidroviario.codigo)))
     LEFT JOIN concessao.ordem_servico_hidroviario__linha_hidroviario ON ((linha_hidroviario.codigo = ordem_servico_hidroviario__linha_hidroviario.linha_hidroviario_codigo)))
     LEFT JOIN concessao.ordem_servico_hidroviario ON ((ordem_servico_hidroviario.numero = ordem_servico_hidroviario__linha_hidroviario.ordem_servico_hidroviario_numero)));


ALTER TABLE concessao.cabecalho_rel_horario_itinerario_hidroviario_site OWNER TO metroplan;

--
-- Name: cabecalho_rel_horario_itinerario_old; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.cabecalho_rel_horario_itinerario_old AS
 SELECT linha.codigo AS linha_codigo,
    linha.nome AS linha_nome,
    empresa_codigo.codigo AS empresa_codigo,
    empresa.nome AS empresa_nome,
    linha.via,
    linha.linha_modalidade_nome,
    COALESCE(linha.terminal_ida, ''::text) AS terminal_ida,
    COALESCE(linha.terminal_volta, ''::text) AS terminal_volta,
    to_char((COALESCE(linha.extensao_1a, COALESCE(linha.extensao_3a, (0)::numeric)) + COALESCE(linha.extensao_1b, COALESCE(linha.extensao_3b, (0)::numeric))), 'FM999990D00'::text) AS extensao_1,
    to_char((COALESCE(linha.extensao_2a, (0)::numeric) + COALESCE(linha.extensao_2b, (0)::numeric)), 'FM999990D00'::text) AS extensao_2,
    COALESCE(linha.tempo_viagem_1, COALESCE(linha.tempo_viagem_3, 0)) AS tempo_viagem_1,
    COALESCE(linha.tempo_viagem_2, 0) AS tempo_viagem_2,
    concessao.status_linha(linha.codigo, ('now'::text)::date, ('now'::text)::date) AS linha_situacao_nome,
    linha.municipio_nome_origem,
    linha.municipio_nome_destino,
    concessao.formata_os(ordem_servico.numero) AS ordem_servico_numero,
    ordem_servico__linha.ordem_servico_numero AS os_crua,
    to_char((ordem_servico.data_emissao)::timestamp with time zone, 'DD/MM/YYYY'::text) AS data_emissao,
    to_char((ordem_servico.data_vigencia)::timestamp with time zone, 'DD/MM/YYYY'::text) AS data_vigencia,
    to_char((ordem_servico__linha.data_validade)::timestamp with time zone, 'DD/MM/YYYY'::text) AS data_validade,
    linha.data_inclusao,
    linha.data_exclusao,
    linha.restricoes,
    linha.observacoes,
    linha.circular,
    linha.tarifa,
    replace((linha.tarifa)::text, '.'::text, ','::text) AS starifa
   FROM ((((geral.empresa
     JOIN geral.empresa_codigo ON ((empresa_codigo.empresa_cnpj = empresa.cnpj)))
     JOIN concessao.linha ON ((linha.empresa_codigo_codigo = empresa_codigo.codigo)))
     LEFT JOIN concessao.ordem_servico__linha ON ((linha.codigo = ordem_servico__linha.linha_codigo)))
     LEFT JOIN concessao.ordem_servico ON ((ordem_servico.numero = ordem_servico__linha.ordem_servico_numero)))
  ORDER BY ordem_servico.data_emissao DESC;


ALTER TABLE concessao.cabecalho_rel_horario_itinerario_old OWNER TO metroplan;

--
-- Name: cabecalho_rel_horario_itinerario_site; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.cabecalho_rel_horario_itinerario_site AS
 SELECT linha.codigo AS linha_codigo,
    linha.nome AS linha_nome,
    empresa_codigo.codigo AS empresa_codigo,
    empresa.nome AS empresa_nome,
    linha.via,
    linha.linha_modalidade_nome,
    linha.terminal_ida,
    linha.terminal_volta,
        CASE
            WHEN ((linha.data_exclusao IS NULL) OR (linha.data_exclusao > now())) THEN 'LINHA EM OPERAÇÃO'::text
            ELSE 'LINHA SUSPENSA'::text
        END AS linha_situacao_nome,
    linha.municipio_nome_origem,
    linha.municipio_nome_destino
   FROM ((((geral.empresa
     JOIN geral.empresa_codigo ON ((empresa_codigo.empresa_cnpj = empresa.cnpj)))
     JOIN concessao.linha ON ((linha.empresa_codigo_codigo = empresa_codigo.codigo)))
     LEFT JOIN concessao.ordem_servico__linha ON ((linha.codigo = ordem_servico__linha.linha_codigo)))
     LEFT JOIN concessao.ordem_servico ON ((ordem_servico.numero = ordem_servico__linha.ordem_servico_numero)));


ALTER TABLE concessao.cabecalho_rel_horario_itinerario_site OWNER TO metroplan;

--
-- Name: concessao_veiculo_tipo; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.concessao_veiculo_tipo (
    nome text NOT NULL
);


ALTER TABLE concessao.concessao_veiculo_tipo OWNER TO metroplan;

--
-- Name: TABLE concessao_veiculo_tipo; Type: COMMENT; Schema: concessao; Owner: metroplan
--

COMMENT ON TABLE concessao.concessao_veiculo_tipo IS 'Trocar para MICRO-ÔNIBUS';


--
-- Name: declaracao; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.declaracao (
    id integer NOT NULL,
    placa text,
    chassi text,
    data date,
    processo text,
    empresa text,
    prefixo integer
);


ALTER TABLE concessao.declaracao OWNER TO metroplan;

--
-- Name: declaracao_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.declaracao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.declaracao_id_seq OWNER TO metroplan;

--
-- Name: declaracao_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.declaracao_id_seq OWNED BY concessao.declaracao.id;


--
-- Name: eixo; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.eixo (
    nome text NOT NULL,
    migra_codigo integer
);


ALTER TABLE concessao.eixo OWNER TO metroplan;

--
-- Name: TABLE eixo; Type: COMMENT; Schema: concessao; Owner: metroplan
--

COMMENT ON TABLE concessao.eixo IS 'apagar migra_codigo apos migracao?';


--
-- Name: embarcacao; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.embarcacao (
    registro text NOT NULL,
    prefixo text,
    embarcacao_tipo_nome text,
    embarcacao_modelo_nome text,
    embarcacao_qualidade_nome text,
    ano_fabricacao integer,
    tipo_marca_motor_1 text,
    tipo_marca_motor_2 text,
    potencia_propulsiva_total integer,
    potencia_eletrica integer,
    embarcacao_material_casco_nome text,
    cor_principal_nome text,
    cor_secundaria_nome text,
    comprimento numeric(5,2),
    veiculo_combustivel_nome text,
    numero_portas integer,
    lugares_sentados integer,
    lugares_em_pe integer,
    autorizacao_carga boolean,
    acessibilidade boolean,
    navegacao_instrumentos boolean,
    iluminacao_noturna boolean,
    alarme_incendio boolean,
    poltrona_reclinavel boolean,
    ar_condicionado boolean,
    outros text,
    empresa_codigo_hidroviario_codigo text
);


ALTER TABLE concessao.embarcacao OWNER TO metroplan;

--
-- Name: embarcacao_material_casco; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.embarcacao_material_casco (
    nome text NOT NULL
);


ALTER TABLE concessao.embarcacao_material_casco OWNER TO metroplan;

--
-- Name: embarcacao_modelo; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.embarcacao_modelo (
    nome text NOT NULL
);


ALTER TABLE concessao.embarcacao_modelo OWNER TO metroplan;

--
-- Name: embarcacao_qualidade; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.embarcacao_qualidade (
    nome text NOT NULL
);


ALTER TABLE concessao.embarcacao_qualidade OWNER TO metroplan;

--
-- Name: embarcacao_tipo; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.embarcacao_tipo (
    nome text NOT NULL
);


ALTER TABLE concessao.embarcacao_tipo OWNER TO metroplan;

--
-- Name: empresa_hidroviario_diretor; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.empresa_hidroviario_diretor (
    empresa_hidroviario_cnpj text NOT NULL,
    nome text NOT NULL,
    ordem integer NOT NULL
);


ALTER TABLE concessao.empresa_hidroviario_diretor OWNER TO metroplan;

--
-- Name: horario_verao; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.horario_verao (
    horario_verao_id integer NOT NULL,
    linha_codigo text NOT NULL,
    horario time without time zone,
    ida boolean,
    sabado boolean,
    domingo_feriado boolean,
    observacoes character varying,
    apdf boolean,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    dia_inicio integer DEFAULT 1,
    mes_inicio integer DEFAULT 1,
    dia_fim integer DEFAULT 31,
    mes_fim integer DEFAULT 12
);


ALTER TABLE concessao.horario_verao OWNER TO metroplan;

--
-- Name: horario_com_verao; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.horario_com_verao AS
 SELECT horario.horario_id,
    horario.linha_codigo,
    horario.horario,
    horario.ida,
    horario.sabado,
    horario.domingo_feriado,
    horario.observacoes,
    horario.apdf,
    horario.data_inclusao,
    horario.data_exclusao,
    horario.dia_inicio,
    horario.mes_inicio,
    horario.dia_fim,
    horario.mes_fim
   FROM concessao.horario
UNION
 SELECT horario_verao.horario_verao_id AS horario_id,
    horario_verao.linha_codigo,
    horario_verao.horario,
    horario_verao.ida,
    horario_verao.sabado,
    horario_verao.domingo_feriado,
    horario_verao.observacoes,
    horario_verao.apdf,
    horario_verao.data_inclusao,
    horario_verao.data_exclusao,
    horario_verao.dia_inicio,
    horario_verao.mes_inicio,
    horario_verao.dia_fim,
    horario_verao.mes_fim
   FROM concessao.horario_verao;


ALTER TABLE concessao.horario_com_verao OWNER TO metroplan;

--
-- Name: horario_hidroviario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.horario_hidroviario (
    horario_id integer NOT NULL,
    linha_hidroviario_codigo text NOT NULL,
    horario time without time zone,
    ida boolean,
    sabado boolean,
    domingo_feriado boolean,
    observacoes character varying,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    dia_inicio integer DEFAULT 1,
    mes_inicio integer DEFAULT 1,
    dia_fim integer DEFAULT 31,
    mes_fim integer DEFAULT 12
);


ALTER TABLE concessao.horario_hidroviario OWNER TO metroplan;

--
-- Name: horario_hidroviario_horario_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.horario_hidroviario_horario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.horario_hidroviario_horario_id_seq OWNER TO metroplan;

--
-- Name: horario_hidroviario_horario_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.horario_hidroviario_horario_id_seq OWNED BY concessao.horario_hidroviario.horario_id;


--
-- Name: horario_horario_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.horario_horario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.horario_horario_id_seq OWNER TO metroplan;

--
-- Name: horario_horario_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.horario_horario_id_seq OWNED BY concessao.horario.horario_id;


--
-- Name: horario_semana; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.horario_semana (
    horario_id integer NOT NULL,
    segunda boolean NOT NULL,
    terca boolean NOT NULL,
    quarta boolean NOT NULL,
    quinta boolean NOT NULL,
    sexta boolean NOT NULL,
    sabado boolean NOT NULL,
    domingo boolean NOT NULL,
    feriado boolean NOT NULL
);


ALTER TABLE concessao.horario_semana OWNER TO metroplan;

--
-- Name: horario_verao_hvid_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.horario_verao_hvid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.horario_verao_hvid_seq OWNER TO metroplan;

--
-- Name: horario_verao_hvid_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.horario_verao_hvid_seq OWNED BY concessao.horario_verao.horario_verao_id;


--
-- Name: itinerario_verao; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.itinerario_verao (
    itinerario_verao_id integer NOT NULL,
    ordem integer NOT NULL,
    ida boolean NOT NULL,
    linha_codigo text,
    logradouro_nome text NOT NULL,
    municipio_nome text,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    secao boolean DEFAULT false NOT NULL,
    logradouro_tipo text
);


ALTER TABLE concessao.itinerario_verao OWNER TO metroplan;

--
-- Name: itinerario_com_verao; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.itinerario_com_verao AS
 SELECT itinerario.itinerario_id,
    itinerario.ordem,
    itinerario.ida,
    itinerario.linha_codigo,
    itinerario.logradouro_nome,
    itinerario.municipio_nome,
    itinerario.data_inclusao,
    itinerario.data_exclusao,
    itinerario.secao,
    itinerario.logradouro_tipo
   FROM concessao.itinerario
UNION
 SELECT itinerario_verao.itinerario_verao_id AS itinerario_id,
    itinerario_verao.ordem,
    itinerario_verao.ida,
    itinerario_verao.linha_codigo,
    itinerario_verao.logradouro_nome,
    itinerario_verao.municipio_nome,
    itinerario_verao.data_inclusao,
    itinerario_verao.data_exclusao,
    itinerario_verao.secao,
    itinerario_verao.logradouro_tipo
   FROM concessao.itinerario_verao;


ALTER TABLE concessao.itinerario_com_verao OWNER TO metroplan;

--
-- Name: itinerario_hidroviario; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.itinerario_hidroviario (
    itinerario_hidroviario_id integer NOT NULL,
    ordem integer NOT NULL,
    ida boolean NOT NULL,
    linha_hidroviario_codigo text,
    logradouro_nome text NOT NULL,
    municipio_nome text,
    data_inclusao date DEFAULT now(),
    data_exclusao date,
    logradouro_tipo text
);


ALTER TABLE concessao.itinerario_hidroviario OWNER TO metroplan;

--
-- Name: COLUMN itinerario_hidroviario.logradouro_nome; Type: COMMENT; Schema: concessao; Owner: metroplan
--

COMMENT ON COLUMN concessao.itinerario_hidroviario.logradouro_nome IS 'NÃO ESTÁ LINKADO A logradouro AINDA!';


--
-- Name: itinerario_hidroviario_itinerario_hidroviario_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.itinerario_hidroviario_itinerario_hidroviario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.itinerario_hidroviario_itinerario_hidroviario_id_seq OWNER TO metroplan;

--
-- Name: itinerario_hidroviario_itinerario_hidroviario_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.itinerario_hidroviario_itinerario_hidroviario_id_seq OWNED BY concessao.itinerario_hidroviario.itinerario_hidroviario_id;


--
-- Name: itinerario_itinerario_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.itinerario_itinerario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.itinerario_itinerario_id_seq OWNER TO metroplan;

--
-- Name: itinerario_itinerario_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.itinerario_itinerario_id_seq OWNED BY concessao.itinerario.itinerario_id;


--
-- Name: itinerario_verao_ivid_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.itinerario_verao_ivid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.itinerario_verao_ivid_seq OWNER TO metroplan;

--
-- Name: itinerario_verao_ivid_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.itinerario_verao_ivid_seq OWNED BY concessao.itinerario_verao.itinerario_verao_id;


--
-- Name: linha_caracteristica; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.linha_caracteristica (
    nome text NOT NULL
);


ALTER TABLE concessao.linha_caracteristica OWNER TO metroplan;

--
-- Name: linha_historico_backup; Type: TABLE; Schema: concessao; Owner: postgres
--

CREATE TABLE concessao.linha_historico_backup (
    id integer,
    linha_id integer,
    linha_codigo text,
    data_historico_inicio date,
    data_historico_fim date,
    linha_nome text,
    empresa_codigo text,
    empresa_nome text,
    via text,
    linha_modalidade_nome text,
    terminal_ida text,
    terminal_volta text,
    extensao_1a numeric(7,2),
    extensao_1b numeric(7,2),
    extensao_2a numeric(7,2),
    extensao_2b numeric(7,2),
    extensao_3a numeric(7,2),
    extensao_3b numeric(7,2),
    tempo_viagem_1 integer,
    tempo_viagem_2 integer,
    tempo_viagem_3 integer,
    linha_situacao_nome text,
    municipio_nome_origem text,
    municipio_nome_destino text,
    ordem_servico_numero text,
    os_crua text,
    data_emissao date,
    data_vigencia date,
    data_validade date,
    data_inclusao date,
    data_exclusao date,
    restricoes text,
    observacoes text,
    circular boolean,
    tarifa numeric
);


ALTER TABLE concessao.linha_historico_backup OWNER TO postgres;

--
-- Name: linha_historico_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.linha_historico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.linha_historico_id_seq OWNER TO metroplan;

--
-- Name: linha_historico_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.linha_historico_id_seq OWNED BY concessao.linha_historico.id;


--
-- Name: linha_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.linha_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.linha_id_seq OWNER TO metroplan;

--
-- Name: linha_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.linha_id_seq OWNED BY concessao.linha.id;


--
-- Name: linha_modalidade; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.linha_modalidade (
    nome text NOT NULL
);


ALTER TABLE concessao.linha_modalidade OWNER TO metroplan;

--
-- Name: linha_servico; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.linha_servico (
    nome text NOT NULL,
    codigo text
);


ALTER TABLE concessao.linha_servico OWNER TO metroplan;

--
-- Name: mostra_verao; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.mostra_verao (
    id integer NOT NULL,
    usuario text,
    mostrar boolean,
    todos boolean
);


ALTER TABLE concessao.mostra_verao OWNER TO metroplan;

--
-- Name: mostra_verao_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.mostra_verao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.mostra_verao_id_seq OWNER TO metroplan;

--
-- Name: mostra_verao_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.mostra_verao_id_seq OWNED BY concessao.mostra_verao.id;


--
-- Name: municipios_linhas; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.municipios_linhas AS
 SELECT itinerario.linha_codigo AS linha,
    itinerario.municipio_nome AS municipio,
    linha.empresa_codigo_codigo AS empresa
   FROM concessao.itinerario,
    concessao.linha
  WHERE (geral.intersecta_exclusao(linha.data_inclusao, linha.data_exclusao, (now())::date, (now())::date) AND geral.intersecta_exclusao(itinerario.data_inclusao, itinerario.data_exclusao, (now())::date, (now())::date) AND (itinerario.linha_codigo = linha.codigo))
  GROUP BY linha.empresa_codigo_codigo, itinerario.linha_codigo, itinerario.municipio_nome
  ORDER BY linha.empresa_codigo_codigo, itinerario.municipio_nome, itinerario.linha_codigo;


ALTER TABLE concessao.municipios_linhas OWNER TO metroplan;

--
-- Name: ordem_servico__linha_ordem_servico__linha_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.ordem_servico__linha_ordem_servico__linha_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.ordem_servico__linha_ordem_servico__linha_id_seq OWNER TO metroplan;

--
-- Name: ordem_servico__linha_ordem_servico__linha_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.ordem_servico__linha_ordem_servico__linha_id_seq OWNED BY concessao.ordem_servico__linha.ordem_servico__linha_id;


--
-- Name: ordem_servico_assunto; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.ordem_servico_assunto (
    descricao text NOT NULL
);


ALTER TABLE concessao.ordem_servico_assunto OWNER TO metroplan;

--
-- Name: ordem_servico_hidroviario__li_ordem_servico_hidroviario__li_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.ordem_servico_hidroviario__li_ordem_servico_hidroviario__li_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.ordem_servico_hidroviario__li_ordem_servico_hidroviario__li_seq OWNER TO metroplan;

--
-- Name: ordem_servico_hidroviario__li_ordem_servico_hidroviario__li_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.ordem_servico_hidroviario__li_ordem_servico_hidroviario__li_seq OWNED BY concessao.ordem_servico_hidroviario__linha_hidroviario.ordem_servico_hidroviario__linha_hidroviario_id;


--
-- Name: municipio; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.municipio (
    nome text NOT NULL,
    regiao_codigo text
);


ALTER TABLE geral.municipio OWNER TO metroplan;

--
-- Name: origem_destino_linha; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.origem_destino_linha AS
 SELECT DISTINCT
        CASE
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN
            CASE
                WHEN (linha.municipio_nome_origem = linha.municipio_nome_destino) THEN linha.municipio_nome_origem
                ELSE ((linha.municipio_nome_origem || ' / '::text) || linha.municipio_nome_destino)
            END
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NULL)) THEN linha.municipio_nome_origem
            WHEN ((linha.municipio_nome_origem IS NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN linha.municipio_nome_destino
            ELSE NULL::text
        END AS origem_destino,
    m1.regiao_codigo AS regiao1,
    m2.regiao_codigo AS regiao2
   FROM concessao.linha,
    geral.municipio m1,
    geral.municipio m2
  WHERE (((linha.municipio_nome_origem IS NOT NULL) OR (linha.municipio_nome_destino IS NOT NULL)) AND (linha.municipio_nome_origem = m1.nome) AND (linha.municipio_nome_destino = m2.nome))
  ORDER BY
        CASE
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN
            CASE
                WHEN (linha.municipio_nome_origem = linha.municipio_nome_destino) THEN linha.municipio_nome_origem
                ELSE ((linha.municipio_nome_origem || ' / '::text) || linha.municipio_nome_destino)
            END
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NULL)) THEN linha.municipio_nome_origem
            WHEN ((linha.municipio_nome_origem IS NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN linha.municipio_nome_destino
            ELSE NULL::text
        END;


ALTER TABLE concessao.origem_destino_linha OWNER TO metroplan;

--
-- Name: origem_destino_linha_por_linha; Type: VIEW; Schema: concessao; Owner: metroplan
--

CREATE VIEW concessao.origem_destino_linha_por_linha AS
 SELECT DISTINCT
        CASE
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN
            CASE
                WHEN (linha.municipio_nome_origem = linha.municipio_nome_destino) THEN linha.municipio_nome_origem
                ELSE ((linha.municipio_nome_origem || ' / '::text) || linha.municipio_nome_destino)
            END
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NULL)) THEN linha.municipio_nome_origem
            WHEN ((linha.municipio_nome_origem IS NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN linha.municipio_nome_destino
            ELSE NULL::text
        END AS origem_destino,
    m1.regiao_codigo AS regiao1,
    m2.regiao_codigo AS regiao2,
    linha.codigo AS linha_codigo
   FROM concessao.linha,
    geral.municipio m1,
    geral.municipio m2
  WHERE (((linha.municipio_nome_origem IS NOT NULL) OR (linha.municipio_nome_destino IS NOT NULL)) AND (linha.municipio_nome_origem = m1.nome) AND (linha.municipio_nome_destino = m2.nome))
  ORDER BY
        CASE
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN
            CASE
                WHEN (linha.municipio_nome_origem = linha.municipio_nome_destino) THEN linha.municipio_nome_origem
                ELSE ((linha.municipio_nome_origem || ' / '::text) || linha.municipio_nome_destino)
            END
            WHEN ((linha.municipio_nome_origem IS NOT NULL) AND (linha.municipio_nome_destino IS NULL)) THEN linha.municipio_nome_origem
            WHEN ((linha.municipio_nome_origem IS NULL) AND (linha.municipio_nome_destino IS NOT NULL)) THEN linha.municipio_nome_destino
            ELSE NULL::text
        END;


ALTER TABLE concessao.origem_destino_linha_por_linha OWNER TO metroplan;

--
-- Name: parecer_tecnico; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.parecer_tecnico (
    processo text NOT NULL,
    linha_codigo text,
    ordem_servico_assunto_descricao text,
    data date,
    texto text,
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE concessao.parecer_tecnico OWNER TO metroplan;

--
-- Name: qualidade_veiculo_qualidade_veiculo_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.qualidade_veiculo_qualidade_veiculo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.qualidade_veiculo_qualidade_veiculo_id_seq OWNER TO metroplan;

--
-- Name: resolucao_cetm_resolucao_cetm_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.resolucao_cetm_resolucao_cetm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.resolucao_cetm_resolucao_cetm_id_seq OWNER TO metroplan;

--
-- Name: secao_tarifaria; Type: TABLE; Schema: concessao; Owner: metroplan
--

CREATE TABLE concessao.secao_tarifaria (
    secao_tarifaria_id integer NOT NULL,
    inicio_itinerario_id integer NOT NULL,
    fim_itinerario_id integer NOT NULL,
    valor numeric(12,2)
);


ALTER TABLE concessao.secao_tarifaria OWNER TO metroplan;

--
-- Name: secao_tarifaria_secao_tarifaria_id_seq; Type: SEQUENCE; Schema: concessao; Owner: metroplan
--

CREATE SEQUENCE concessao.secao_tarifaria_secao_tarifaria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE concessao.secao_tarifaria_secao_tarifaria_id_seq OWNER TO metroplan;

--
-- Name: secao_tarifaria_secao_tarifaria_id_seq; Type: SEQUENCE OWNED BY; Schema: concessao; Owner: metroplan
--

ALTER SEQUENCE concessao.secao_tarifaria_secao_tarifaria_id_seq OWNED BY concessao.secao_tarifaria.secao_tarifaria_id;


--
-- Name: documento; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento (
    id integer NOT NULL,
    documento_tipo_nome text NOT NULL,
    caminho text NOT NULL,
    tamanho bigint,
    hash character(32),
    data_upload timestamp without time zone DEFAULT now(),
    validade date,
    fluxo_pendencia_id integer,
    aprovado_em timestamp without time zone
);


ALTER TABLE eventual.documento OWNER TO postgres;

--
-- Name: documento_empresa; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento_empresa (
    id integer NOT NULL,
    empresa_cnpj text NOT NULL
);


ALTER TABLE eventual.documento_empresa OWNER TO postgres;

--
-- Name: documento_id_seq; Type: SEQUENCE; Schema: eventual; Owner: postgres
--

CREATE SEQUENCE eventual.documento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE eventual.documento_id_seq OWNER TO postgres;

--
-- Name: documento_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: postgres
--

ALTER SEQUENCE eventual.documento_id_seq OWNED BY eventual.documento.id;


--
-- Name: documento_motorista; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento_motorista (
    id integer NOT NULL,
    motorista_id integer NOT NULL
);


ALTER TABLE eventual.documento_motorista OWNER TO postgres;

--
-- Name: documento_motorista_id_seq; Type: SEQUENCE; Schema: eventual; Owner: postgres
--

CREATE SEQUENCE eventual.documento_motorista_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE eventual.documento_motorista_id_seq OWNER TO postgres;

--
-- Name: documento_motorista_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: postgres
--

ALTER SEQUENCE eventual.documento_motorista_id_seq OWNED BY eventual.documento_motorista.id;


--
-- Name: documento_tipo; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento_tipo (
    nome text NOT NULL,
    descricao text
);


ALTER TABLE eventual.documento_tipo OWNER TO postgres;

--
-- Name: documento_tipo_permissao; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento_tipo_permissao (
    tipo_nome text NOT NULL,
    entidade_tipo text NOT NULL,
    CONSTRAINT documento_tipo_permissao_entidade_tipo_check CHECK ((entidade_tipo = ANY (ARRAY['empresa'::text, 'usuario'::text, 'veiculo'::text])))
);


ALTER TABLE eventual.documento_tipo_permissao OWNER TO postgres;

--
-- Name: documento_usuario; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento_usuario (
    id integer NOT NULL,
    usuario_id integer NOT NULL
);


ALTER TABLE eventual.documento_usuario OWNER TO postgres;

--
-- Name: documento_veiculo; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento_veiculo (
    id integer NOT NULL,
    veiculo_placa text NOT NULL
);


ALTER TABLE eventual.documento_veiculo OWNER TO postgres;

--
-- Name: documento_viagem; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.documento_viagem (
    id integer NOT NULL,
    viagem_id integer NOT NULL
);


ALTER TABLE eventual.documento_viagem OWNER TO postgres;

--
-- Name: fluxo_pendencia; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.fluxo_pendencia (
    id integer NOT NULL,
    criado_em timestamp without time zone DEFAULT now() NOT NULL,
    entidade_tipo text NOT NULL,
    entidade_id text NOT NULL,
    status text NOT NULL,
    analista text,
    motivo text
);


ALTER TABLE eventual.fluxo_pendencia OWNER TO postgres;

--
-- Name: fluxo_pendencia_id_seq; Type: SEQUENCE; Schema: eventual; Owner: postgres
--

CREATE SEQUENCE eventual.fluxo_pendencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE eventual.fluxo_pendencia_id_seq OWNER TO postgres;

--
-- Name: fluxo_pendencia_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: postgres
--

ALTER SEQUENCE eventual.fluxo_pendencia_id_seq OWNED BY eventual.fluxo_pendencia.id;


--
-- Name: motorista; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.motorista (
    id integer NOT NULL,
    empresa_cnpj text NOT NULL,
    cpf text NOT NULL,
    cnh text NOT NULL,
    email text,
    nome text,
    data_cadastro timestamp without time zone DEFAULT now(),
    eventual_status text
);


ALTER TABLE eventual.motorista OWNER TO postgres;

--
-- Name: motorista_id_seq; Type: SEQUENCE; Schema: eventual; Owner: postgres
--

CREATE SEQUENCE eventual.motorista_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE eventual.motorista_id_seq OWNER TO postgres;

--
-- Name: motorista_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: postgres
--

ALTER SEQUENCE eventual.motorista_id_seq OWNED BY eventual.motorista.id;


--
-- Name: passageiro; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.passageiro (
    id integer NOT NULL,
    viagem_id integer NOT NULL,
    nome text NOT NULL,
    cpf text NOT NULL
);


ALTER TABLE eventual.passageiro OWNER TO postgres;

--
-- Name: passageiro_id_seq; Type: SEQUENCE; Schema: eventual; Owner: postgres
--

CREATE SEQUENCE eventual.passageiro_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE eventual.passageiro_id_seq OWNER TO postgres;

--
-- Name: passageiro_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: postgres
--

ALTER SEQUENCE eventual.passageiro_id_seq OWNED BY eventual.passageiro.id;


--
-- Name: status_pendencia; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.status_pendencia (
    status text NOT NULL,
    nome text NOT NULL
);


ALTER TABLE eventual.status_pendencia OWNER TO postgres;

--
-- Name: tipo_entidade_pendencia; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.tipo_entidade_pendencia (
    tipo text NOT NULL,
    descricao text NOT NULL
);


ALTER TABLE eventual.tipo_entidade_pendencia OWNER TO postgres;

--
-- Name: v_pendencia_atual; Type: VIEW; Schema: eventual; Owner: postgres
--

CREATE VIEW eventual.v_pendencia_atual AS
 SELECT DISTINCT ON (fluxo_pendencia.entidade_tipo, fluxo_pendencia.entidade_id) fluxo_pendencia.id,
    fluxo_pendencia.entidade_tipo,
    fluxo_pendencia.entidade_id,
    fluxo_pendencia.status,
    fluxo_pendencia.analista,
    fluxo_pendencia.criado_em,
    fluxo_pendencia.motivo
   FROM eventual.fluxo_pendencia
  ORDER BY fluxo_pendencia.entidade_tipo, fluxo_pendencia.entidade_id, fluxo_pendencia.criado_em DESC;


ALTER TABLE eventual.v_pendencia_atual OWNER TO postgres;

--
-- Name: viagem; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.viagem (
    id integer NOT NULL,
    nome_contratante text NOT NULL,
    cpf_cnpj_contratante text NOT NULL,
    regiao_codigo text NOT NULL,
    municipio_origem text NOT NULL,
    municipio_destino text NOT NULL,
    ida_em timestamp without time zone NOT NULL,
    volta_em timestamp without time zone NOT NULL,
    viagem_tipo text NOT NULL,
    veiculo_placa text NOT NULL,
    motorista_id integer NOT NULL,
    motorista_aux_id integer,
    descricao text
);


ALTER TABLE eventual.viagem OWNER TO postgres;

--
-- Name: viagem_id_seq; Type: SEQUENCE; Schema: eventual; Owner: postgres
--

CREATE SEQUENCE eventual.viagem_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE eventual.viagem_id_seq OWNER TO postgres;

--
-- Name: viagem_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: postgres
--

ALTER SEQUENCE eventual.viagem_id_seq OWNED BY eventual.viagem.id;


--
-- Name: viagem_tipo; Type: TABLE; Schema: eventual; Owner: postgres
--

CREATE TABLE eventual.viagem_tipo (
    nome text NOT NULL
);


ALTER TABLE eventual.viagem_tipo OWNER TO postgres;

--
-- Name: autorizacao; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.autorizacao (
    codigo text DEFAULT fretamento.proxima_autorizacao() NOT NULL,
    veiculo_placa text NOT NULL,
    data_inicio date NOT NULL,
    processo text NOT NULL,
    contrato_codigo integer,
    renovacao boolean NOT NULL,
    empresa_cnpj_sublocacao text,
    codigo_barras text,
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE fretamento.autorizacao OWNER TO metroplan;

--
-- Name: autorizacao_emitida; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.autorizacao_emitida (
    autorizacao_emitida_id integer NOT NULL,
    data timestamp without time zone DEFAULT now() NOT NULL,
    contrato_codigo integer NOT NULL,
    veiculo_placa text NOT NULL,
    usuario_nome text
);


ALTER TABLE fretamento.autorizacao_emitida OWNER TO metroplan;

--
-- Name: autorizacao_emitida_autorizacao_emitida_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.autorizacao_emitida_autorizacao_emitida_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.autorizacao_emitida_autorizacao_emitida_id_seq OWNER TO metroplan;

--
-- Name: autorizacao_emitida_autorizacao_emitida_id_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.autorizacao_emitida_autorizacao_emitida_id_seq OWNED BY fretamento.autorizacao_emitida.autorizacao_emitida_id;


--
-- Name: contrato; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.contrato (
    codigo integer NOT NULL,
    empresa_cnpj text,
    contratante_codigo text NOT NULL,
    data_inicio date,
    data_fim date,
    servico_nome text,
    processo text,
    migra_codigo_access integer,
    observacoes text,
    regiao_codigo text,
    numero_passageiros integer,
    entidade_estudantil text,
    inativo boolean DEFAULT false NOT NULL,
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE fretamento.contrato OWNER TO metroplan;

--
-- Name: COLUMN contrato.migra_codigo_access; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON COLUMN fretamento.contrato.migra_codigo_access IS 'ainda necessário?';


--
-- Name: fretamento_processo; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.fretamento_processo (
    codigo text NOT NULL,
    data_abertura date NOT NULL,
    data_encerramento date,
    ativo boolean NOT NULL,
    motivo_encerramento text,
    CONSTRAINT codigo_length_chk CHECK ((length(codigo) = 11))
);


ALTER TABLE fretamento.fretamento_processo OWNER TO metroplan;

--
-- Name: laudo_vistoria; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.laudo_vistoria (
    laudo_vistoria_id integer NOT NULL,
    numero bigint NOT NULL,
    veiculo_placa text NOT NULL,
    data_emissao date,
    data_validade date,
    processo text,
    renovacao boolean NOT NULL
);


ALTER TABLE fretamento.laudo_vistoria OWNER TO metroplan;

--
-- Name: COLUMN laudo_vistoria.processo; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON COLUMN fretamento.laudo_vistoria.processo IS 'não mais utilizado as of 11/06/2014';


--
-- Name: base_checa; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.base_checa AS
 SELECT contrato.codigo,
    autorizacao.veiculo_placa AS placa,
    contrato.data_inicio AS contrato_data_inicio,
    contrato.data_fim AS contrato_data_fim,
    autorizacao.data_inicio AS autorizacao_data_inicio,
    empresa.data_entrega_documentacao,
    empresa.cnpj,
    laudo_vistoria.data_validade AS laudo_data_validade,
    fretamento_processo.data_encerramento,
    veiculo.data_exclusao_fretamento,
    veiculo.data_vencimento_seguro,
    (LEAST((contrato.data_fim)::timestamp without time zone, (autorizacao.data_inicio + '1 year'::interval), (laudo_vistoria.data_validade)::timestamp without time zone, (fretamento_processo.data_encerramento)::timestamp without time zone, (veiculo.data_exclusao_fretamento)::timestamp without time zone, (veiculo.data_vencimento_seguro)::timestamp without time zone, (empresa.data_entrega_documentacao + '1 year'::interval)))::date AS fim,
    GREATEST(contrato.data_inicio, autorizacao.data_inicio) AS inicio,
    empresa.regiao_codigo AS regiao,
    autorizacao.renovacao AS autorizacao_renovacao,
    laudo_vistoria.renovacao AS laudo_renovacao,
    contrato.servico_nome,
    veiculo.numero_lugares,
    contrato.numero_passageiros,
    contrato.regiao_codigo
   FROM fretamento.contrato,
    fretamento.autorizacao,
    geral.veiculo,
    geral.empresa,
    fretamento.laudo_vistoria,
    fretamento.fretamento_processo
  WHERE ((contrato.codigo = autorizacao.contrato_codigo) AND (autorizacao.veiculo_placa = veiculo.placa) AND (empresa.cnpj = veiculo.empresa_cnpj) AND (laudo_vistoria.veiculo_placa = veiculo.placa) AND (fretamento_processo.codigo = empresa.processo));


ALTER TABLE fretamento.base_checa OWNER TO metroplan;

--
-- Name: base_contratos; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.base_contratos AS
 SELECT contrato.codigo,
    contrato.data_inicio,
    contrato.data_fim,
    autorizacao.veiculo_placa,
    contrato.empresa_cnpj,
    empresa.regiao_codigo,
    empresa.nome
   FROM fretamento.contrato,
    fretamento.autorizacao,
    geral.empresa
  WHERE ((contrato.codigo = autorizacao.contrato_codigo) AND (contrato.empresa_cnpj = empresa.cnpj));


ALTER TABLE fretamento.base_contratos OWNER TO metroplan;

--
-- Name: base_contratos_2; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.base_contratos_2 AS
 SELECT contrato.codigo,
    contrato.data_inicio,
    contrato.data_fim,
    autorizacao.veiculo_placa,
    contrato.empresa_cnpj,
    empresa.regiao_codigo,
    empresa.nome,
    fretamento.checa_tudo(autorizacao.contrato_codigo, autorizacao.veiculo_placa) AS checa_tudo
   FROM fretamento.contrato,
    fretamento.autorizacao,
    geral.empresa
  WHERE ((contrato.codigo = autorizacao.contrato_codigo) AND (contrato.empresa_cnpj = empresa.cnpj));


ALTER TABLE fretamento.base_contratos_2 OWNER TO metroplan;

--
-- Name: codigo_barras; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.codigo_barras (
    codigo text NOT NULL,
    maximo integer NOT NULL
);


ALTER TABLE fretamento.codigo_barras OWNER TO metroplan;

--
-- Name: TABLE codigo_barras; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON TABLE fretamento.codigo_barras IS 'maximo = numero de repeticoes do codigo';


--
-- Name: busca_barras; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.busca_barras AS
 SELECT autorizacao.codigo AS autorizacao,
    contrato.codigo AS contrato,
    empresa.nome AS empresa,
    codigo_barras.codigo AS codigo_barras,
    codigo_barras.maximo AS repeticoes,
    autorizacao.veiculo_placa AS placa
   FROM (((fretamento.codigo_barras
     LEFT JOIN fretamento.autorizacao ON ((autorizacao.codigo_barras = codigo_barras.codigo)))
     LEFT JOIN fretamento.contrato ON ((contrato.codigo = autorizacao.contrato_codigo)))
     LEFT JOIN geral.empresa ON ((empresa.cnpj = contrato.empresa_cnpj)))
  ORDER BY empresa.nome, contrato.codigo, autorizacao.codigo;


ALTER TABLE fretamento.busca_barras OWNER TO metroplan;

--
-- Name: consulta_veiculo_site; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.consulta_veiculo_site AS
SELECT
    NULL::text AS placa,
    NULL::integer AS crlv,
    NULL::date AS vencimento_seguro,
    NULL::date AS vistoria_data,
    NULL::integer AS contrato_codigo,
    NULL::date AS contrato_vencimento,
    NULL::date AS validade_taxa,
    NULL::text AS empresa;


ALTER TABLE fretamento.consulta_veiculo_site OWNER TO metroplan;

--
-- Name: contratante; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.contratante (
    codigo text NOT NULL,
    nome text,
    municipio_nome text,
    identificacao_nome text,
    numero_usuarios integer,
    observacoes text
);


ALTER TABLE fretamento.contratante OWNER TO metroplan;

--
-- Name: contrato_contrato_codigo_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.contrato_contrato_codigo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.contrato_contrato_codigo_seq OWNER TO metroplan;

--
-- Name: contrato_contrato_codigo_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.contrato_contrato_codigo_seq OWNED BY fretamento.contrato.codigo;


--
-- Name: contrato_itinerario; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.contrato_itinerario (
    itinerario_id integer NOT NULL,
    contrato_codigo integer NOT NULL,
    veiculo_placa text NOT NULL,
    municipio_nome_saida text,
    municipio_nome_chegada text,
    numero_lugares integer,
    numero_viagens integer,
    remanejado boolean NOT NULL
);


ALTER TABLE fretamento.contrato_itinerario OWNER TO metroplan;

--
-- Name: COLUMN contrato_itinerario.itinerario_id; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON COLUMN fretamento.contrato_itinerario.itinerario_id IS 'renomear para contrato_itinerario_id';


--
-- Name: contrato_itinerario_itinerario_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.contrato_itinerario_itinerario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.contrato_itinerario_itinerario_id_seq OWNER TO metroplan;

--
-- Name: contrato_itinerario_itinerario_id_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.contrato_itinerario_itinerario_id_seq OWNED BY fretamento.contrato_itinerario.itinerario_id;


--
-- Name: documento_contratado; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.documento_contratado (
    nome text NOT NULL
);


ALTER TABLE fretamento.documento_contratado OWNER TO metroplan;

--
-- Name: documento_contrato; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.documento_contrato (
    nome text NOT NULL
);


ALTER TABLE fretamento.documento_contrato OWNER TO metroplan;

--
-- Name: documento_veiculo; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.documento_veiculo (
    nome text NOT NULL
);


ALTER TABLE fretamento.documento_veiculo OWNER TO metroplan;

--
-- Name: emplacamento; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.emplacamento (
    placa text,
    chassi text NOT NULL,
    nome text,
    marca text,
    modelo text,
    cor text,
    ano integer,
    processo text,
    cpf_cnpj text,
    data_entrega date DEFAULT now(),
    retorno boolean DEFAULT false NOT NULL,
    data_retorno date
);


ALTER TABLE fretamento.emplacamento OWNER TO metroplan;

--
-- Name: empresas_sublocacao; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.empresas_sublocacao AS
 SELECT DISTINCT veiculo.placa,
    empresa.nome AS empresa,
    empresa.cnpj AS cnpj_subcontratado,
    autorizacao.empresa_cnpj_sublocacao,
        CASE
            WHEN (autorizacao.empresa_cnpj_sublocacao IS NOT NULL) THEN fretamento.pega_subcontratado(veiculo.placa)
            ELSE NULL::text
        END AS empresa_sublocacao
   FROM geral.veiculo,
    geral.empresa,
    fretamento.autorizacao,
    fretamento.contrato
  WHERE ((veiculo.placa = autorizacao.veiculo_placa) AND (veiculo.empresa_cnpj = empresa.cnpj) AND (contrato.empresa_cnpj = empresa.cnpj) AND (fretamento.veiculo_cadastrado(veiculo.placa) = true))
  ORDER BY veiculo.placa;


ALTER TABLE fretamento.empresas_sublocacao OWNER TO metroplan;

--
-- Name: entidade; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.entidade (
    nome text NOT NULL
);


ALTER TABLE fretamento.entidade OWNER TO metroplan;

--
-- Name: fretamento_veiculo_tipo; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.fretamento_veiculo_tipo (
    nome text NOT NULL
);


ALTER TABLE fretamento.fretamento_veiculo_tipo OWNER TO metroplan;

--
-- Name: TABLE fretamento_veiculo_tipo; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON TABLE fretamento.fretamento_veiculo_tipo IS 'Trocar para MICRO-ÔNIBUS';


--
-- Name: ft_todas_empresas; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.ft_todas_empresas AS
 SELECT empresa.cnpj,
    empresa.nome,
    empresa.telefone,
    empresa.fax,
    empresa.cep,
    empresa.email,
    empresa.regiao_codigo,
    empresa.processo,
    empresa.endereco,
    empresa.municipio_nome,
    empresa.nome_simplificado,
    to_char((empresa.data_inicio_operacao)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_inicio_operacao,
    to_char((empresa.data_fim_operacao)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_fim_operacao,
    empresa.inscricao_estadual,
    empresa.garagem_telefone,
    empresa.garagem_cep,
    empresa.observacoes,
    to_char((empresa.data_inclusao_metroplan)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_inclusao_metroplan,
    empresa.garagem_endereco,
    to_char((empresa.data_inclusao)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_inclusao,
    empresa.telefone2,
    empresa.procurador,
    empresa.procurador_endereco,
    empresa.procurador_telefone,
    empresa.procurador_email,
    to_char((empresa.data_entrega_documentacao)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_entrega_documentacao,
    empresa.eh_acordo
   FROM geral.empresa;


ALTER TABLE fretamento.ft_todas_empresas OWNER TO metroplan;

--
-- Name: ft_todos_veiculos; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.ft_todos_veiculos AS
 SELECT veiculo.placa,
    veiculo.chassi_ano,
    veiculo.empresa_cnpj,
    veiculo.empresa_codigo_codigo,
    veiculo.chassi_numero,
    veiculo.veiculo_chassi_nome,
    veiculo.ano_fabricacao,
    to_char((veiculo.data_inclusao_concessao)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_inclusao_concessao,
    to_char((veiculo.data_exclusao_concessao)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_exclusao_concessao,
    veiculo.observacoes,
    to_char((veiculo.data_inclusao_fretamento)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_inclusao_fretamento,
    to_char((veiculo.data_exclusao_fretamento)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_exclusao_fretamento,
    to_char((veiculo.data_inicio_seguro)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_inicio_seguro,
    to_char((veiculo.data_vencimento_seguro)::timestamp with time zone, 'yyyy-mm-ddT00:00:00'::text) AS data_vencimento_seguro,
    veiculo.modelo,
    veiculo.apolice,
    veiculo.seguradora
   FROM geral.veiculo
  WHERE ((veiculo.data_inclusao_fretamento IS NOT NULL) AND (veiculo.data_inicio_seguro IS NOT NULL));


ALTER TABLE fretamento.ft_todos_veiculos OWNER TO metroplan;

--
-- Name: guia; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.guia (
    numero text NOT NULL,
    empresa_cnpj text NOT NULL,
    processo text,
    data date DEFAULT ('now'::text)::date NOT NULL,
    repeticoes integer,
    id integer NOT NULL
);


ALTER TABLE fretamento.guia OWNER TO metroplan;

--
-- Name: guia_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.guia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.guia_id_seq OWNER TO metroplan;

--
-- Name: guia_id_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.guia_id_seq OWNED BY fretamento.guia.id;


--
-- Name: historico; Type: TABLE; Schema: fretamento; Owner: postgres
--

CREATE TABLE fretamento.historico (
    id integer NOT NULL,
    placa text,
    regiao text,
    contrato date,
    seguro date,
    taxa date,
    laudo date,
    data date,
    empresa text,
    servico text,
    passageiros integer,
    lugares integer
);


ALTER TABLE fretamento.historico OWNER TO postgres;

--
-- Name: historico_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.historico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.historico_id_seq OWNER TO metroplan;

--
-- Name: historico_id_seq1; Type: SEQUENCE; Schema: fretamento; Owner: postgres
--

CREATE SEQUENCE fretamento.historico_id_seq1
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.historico_id_seq1 OWNER TO postgres;

--
-- Name: historico_id_seq1; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: postgres
--

ALTER SEQUENCE fretamento.historico_id_seq1 OWNED BY fretamento.historico.id;


--
-- Name: hlp; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.hlp (
    id integer NOT NULL,
    contrato_codigo integer NOT NULL,
    sequencial text DEFAULT fretamento.proxima_hlp() NOT NULL,
    ano integer DEFAULT date_part('year'::text, now()) NOT NULL
);


ALTER TABLE fretamento.hlp OWNER TO metroplan;

--
-- Name: hlp_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.hlp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.hlp_id_seq OWNER TO metroplan;

--
-- Name: hlp_id_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.hlp_id_seq OWNED BY fretamento.hlp.id;


--
-- Name: hlpa; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.hlpa (
    hlpa_id integer NOT NULL,
    autorizacao_codigo text,
    hlp_id integer
);


ALTER TABLE fretamento.hlpa OWNER TO metroplan;

--
-- Name: hlpa_hlpa_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.hlpa_hlpa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.hlpa_hlpa_id_seq OWNER TO metroplan;

--
-- Name: hlpa_hlpa_id_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.hlpa_hlpa_id_seq OWNED BY fretamento.hlpa.hlpa_id;


--
-- Name: identificacao; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.identificacao (
    nome text NOT NULL
);


ALTER TABLE fretamento.identificacao OWNER TO metroplan;

--
-- Name: laudo_vistoria_laudo_vistoria_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.laudo_vistoria_laudo_vistoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.laudo_vistoria_laudo_vistoria_id_seq OWNER TO metroplan;

--
-- Name: laudo_vistoria_laudo_vistoria_id_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.laudo_vistoria_laudo_vistoria_id_seq OWNED BY fretamento.laudo_vistoria.laudo_vistoria_id;


--
-- Name: lista_passageiros; Type: TABLE; Schema: fretamento; Owner: postgres
--

CREATE TABLE fretamento.lista_passageiros (
    contrato_codigo integer NOT NULL,
    lista bytea,
    data_upload timestamp without time zone DEFAULT now()
);


ALTER TABLE fretamento.lista_passageiros OWNER TO postgres;

--
-- Name: lista_subcontratados; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.lista_subcontratados AS
 SELECT fretamento.empresa_por_cnpj(autorizacao.empresa_cnpj_sublocacao) AS empresa_por_cnpj,
    autorizacao.veiculo_placa
   FROM fretamento.autorizacao
  WHERE (((autorizacao.data_inicio + '1 year'::interval) > ('now'::text)::date) AND (autorizacao.empresa_cnpj_sublocacao IS NOT NULL) AND (autorizacao.renovacao = false) AND (fretamento.veiculo_cadastrado(autorizacao.veiculo_placa) = true));


ALTER TABLE fretamento.lista_subcontratados OWNER TO metroplan;

--
-- Name: lista_vencimento_placas; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.lista_vencimento_placas AS
 SELECT DISTINCT ( SELECT contrato.codigo
           FROM fretamento.contrato,
            fretamento.autorizacao
          WHERE ((contrato.codigo = autorizacao.contrato_codigo) AND (autorizacao.veiculo_placa = veiculo.placa))
          ORDER BY contrato.data_fim DESC
         LIMIT 1) AS contrato,
    veiculo.placa,
    veiculo.data_vencimento_seguro AS seguro_validade,
    ( SELECT laudo_vistoria.data_validade
           FROM fretamento.laudo_vistoria
          WHERE (laudo_vistoria.veiculo_placa = veiculo.placa)
          ORDER BY laudo_vistoria.data_validade DESC
         LIMIT 1) AS laudo_validade,
    ( SELECT contrato.data_fim
           FROM fretamento.contrato,
            fretamento.autorizacao
          WHERE ((contrato.codigo = autorizacao.contrato_codigo) AND (autorizacao.veiculo_placa = veiculo.placa))
          ORDER BY contrato.data_fim DESC
         LIMIT 1) AS contrato_validade,
    (( SELECT (autorizacao.data_inicio + '1 year'::interval)
           FROM fretamento.autorizacao
          WHERE (autorizacao.veiculo_placa = veiculo.placa)
          ORDER BY autorizacao.data_inicio DESC
         LIMIT 1))::date AS autorizacao_validade,
    ( SELECT contrato_itinerario.municipio_nome_chegada
           FROM fretamento.contrato_itinerario,
            fretamento.autorizacao
          WHERE ((contrato_itinerario.contrato_codigo = autorizacao.contrato_codigo) AND (autorizacao.veiculo_placa = contrato_itinerario.veiculo_placa) AND (autorizacao.veiculo_placa = veiculo.placa))
          ORDER BY autorizacao.data_inicio DESC
         LIMIT 1) AS municipio_chegada
   FROM geral.veiculo
  WHERE ((veiculo.data_inclusao_fretamento IS NOT NULL) AND (veiculo.data_exclusao_fretamento IS NULL));


ALTER TABLE fretamento.lista_vencimento_placas OWNER TO metroplan;

--
-- Name: qr; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.qr (
    token text NOT NULL,
    veiculo_placa text NOT NULL,
    usuario text NOT NULL,
    data timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE fretamento.qr OWNER TO metroplan;

--
-- Name: raiz; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.raiz AS
 SELECT DISTINCT veiculo.placa,
    veiculo.numero_lugares,
    contrato.servico_nome,
    contrato.codigo AS contrato_codigo,
    fretamento.veiculo_validade_seguro(veiculo.placa) AS validade_seguro,
    fretamento.veiculo_validade_laudo(veiculo.placa) AS validade_laudo,
    fretamento.veiculo_validade_autorizacao(veiculo.placa, contrato.codigo) AS validade_autorizacao,
    fretamento.veiculo_validade_contrato(contrato.codigo) AS validade_contrato,
    empresa.nome AS empresa,
    empresa.cnpj AS empresa_cnpj,
    empresa.regiao_codigo,
    autorizacao.renovacao AS autorizacao_renovacao,
    laudo_vistoria.renovacao AS laudo_renovacao,
    veiculo.chassi_ano,
    veiculo.ano_fabricacao,
    veiculo.data_exclusao_fretamento,
    autorizacao.codigo AS autorizacao_codigo,
    contrato.entidade_estudantil,
    veiculo.data_inclusao_fretamento,
    veiculo.data_inclusao_concessao,
    veiculo.concessao_veiculo_tipo_nome,
    veiculo.classificacao_inmetro_nome,
    veiculo.acordo_codigo
   FROM geral.veiculo,
    fretamento.contrato,
    fretamento.autorizacao,
    geral.empresa,
    fretamento.laudo_vistoria
  WHERE ((veiculo.placa = autorizacao.veiculo_placa) AND (contrato.codigo = autorizacao.contrato_codigo) AND (veiculo.data_inclusao_fretamento IS NOT NULL) AND (empresa.cnpj = contrato.empresa_cnpj) AND (laudo_vistoria.veiculo_placa = veiculo.placa) AND (veiculo.data_vencimento_seguro IS NOT NULL) AND (laudo_vistoria.data_validade IS NOT NULL) AND (autorizacao.data_inicio IS NOT NULL) AND (contrato.data_fim IS NOT NULL));


ALTER TABLE fretamento.raiz OWNER TO metroplan;

--
-- Name: raiz_contagem_vencimentos; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.raiz_contagem_vencimentos AS
 SELECT DISTINCT veiculo.placa,
    veiculo.numero_lugares,
    contrato.servico_nome,
    contrato.codigo AS contrato_codigo,
    fretamento.veiculo_validade_seguro(veiculo.placa) AS validade_seguro,
    fretamento.veiculo_validade_laudo(veiculo.placa) AS validade_laudo,
    fretamento.veiculo_validade_autorizacao(veiculo.placa, contrato.codigo) AS validade_autorizacao,
    fretamento.veiculo_validade_contrato(contrato.codigo) AS validade_contrato,
    empresa.nome AS empresa,
    empresa.cnpj AS empresa_cnpj,
    empresa.regiao_codigo,
    autorizacao.renovacao AS autorizacao_renovacao,
    laudo_vistoria.renovacao AS laudo_renovacao,
    veiculo.chassi_ano,
    veiculo.ano_fabricacao,
    veiculo.data_exclusao_fretamento,
    contrato.codigo
   FROM geral.veiculo,
    fretamento.contrato,
    fretamento.autorizacao,
    geral.empresa,
    fretamento.laudo_vistoria
  WHERE ((veiculo.placa = autorizacao.veiculo_placa) AND (contrato.codigo = autorizacao.contrato_codigo) AND (veiculo.data_inclusao_fretamento IS NOT NULL) AND (empresa.cnpj = contrato.empresa_cnpj) AND (laudo_vistoria.veiculo_placa = veiculo.placa) AND (veiculo.data_vencimento_seguro IS NOT NULL) AND (laudo_vistoria.data_validade IS NOT NULL) AND (autorizacao.data_inicio IS NOT NULL) AND (contrato.data_fim IS NOT NULL))
  ORDER BY veiculo.placa;


ALTER TABLE fretamento.raiz_contagem_vencimentos OWNER TO metroplan;

--
-- Name: raiz_regulares; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.raiz_regulares AS
 SELECT DISTINCT veiculo.placa,
    veiculo.numero_lugares,
    contrato.servico_nome,
    contrato.codigo AS contrato_codigo,
    fretamento.veiculo_validade_seguro(veiculo.placa) AS validade_seguro,
    fretamento.veiculo_validade_laudo(veiculo.placa) AS validade_laudo,
    fretamento.veiculo_validade_autorizacao(veiculo.placa, contrato.codigo) AS validade_autorizacao,
    fretamento.veiculo_validade_contrato(contrato.codigo) AS validade_contrato,
    empresa.nome AS empresa,
    empresa.cnpj AS empresa_cnpj,
    empresa.regiao_codigo,
    autorizacao.renovacao AS autorizacao_renovacao,
    laudo_vistoria.renovacao AS laudo_renovacao,
    veiculo.chassi_ano,
    veiculo.ano_fabricacao,
    veiculo.data_exclusao_fretamento,
    autorizacao.codigo AS autorizacao_codigo,
    contrato.entidade_estudantil
   FROM geral.veiculo,
    fretamento.contrato,
    fretamento.autorizacao,
    geral.empresa,
    fretamento.laudo_vistoria
  WHERE ((veiculo.placa = autorizacao.veiculo_placa) AND (contrato.codigo = autorizacao.contrato_codigo) AND (veiculo.data_inclusao_fretamento IS NOT NULL) AND (empresa.cnpj = contrato.empresa_cnpj) AND (laudo_vistoria.veiculo_placa = veiculo.placa) AND (veiculo.data_vencimento_seguro IS NOT NULL) AND (laudo_vistoria.data_validade IS NOT NULL) AND (autorizacao.data_inicio IS NOT NULL) AND (contrato.data_fim IS NOT NULL) AND (autorizacao.renovacao = false) AND (laudo_vistoria.renovacao = false) AND (fretamento.veiculo_validade_seguro(veiculo.placa) >= ('now'::text)::date) AND (fretamento.veiculo_validade_laudo(veiculo.placa) >= ('now'::text)::date) AND (fretamento.veiculo_validade_autorizacao(veiculo.placa, contrato.codigo) >= ('now'::text)::date) AND (fretamento.veiculo_validade_contrato(contrato.codigo) >= ('now'::text)::date));


ALTER TABLE fretamento.raiz_regulares OWNER TO metroplan;

--
-- Name: raiz_servico_lugares; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.raiz_servico_lugares AS
 SELECT base.regiao_codigo,
    count(DISTINCT base.contrato) AS contratos,
    base.servico_nome,
    sum(base.numero_lugares) AS total_lugares
   FROM ( SELECT DISTINCT contrato.regiao_codigo,
            contrato.codigo AS contrato,
            contrato.servico_nome,
            autorizacao.veiculo_placa,
            veiculo.numero_lugares
           FROM fretamento.autorizacao,
            fretamento.contrato,
            geral.veiculo
          WHERE ((autorizacao.contrato_codigo = contrato.codigo) AND (contrato.servico_nome IS NOT NULL) AND (autorizacao.veiculo_placa = veiculo.placa) AND (contrato.data_fim >= ('now'::text)::date) AND (autorizacao.veiculo_placa IN ( SELECT DISTINCT raiz_contagem_vencimentos.placa
                   FROM fretamento.raiz_contagem_vencimentos
                  WHERE ((raiz_contagem_vencimentos.validade_seguro >= ('now'::text)::date) AND (raiz_contagem_vencimentos.validade_contrato >= ('now'::text)::date) AND (raiz_contagem_vencimentos.validade_laudo >= ('now'::text)::date) AND (raiz_contagem_vencimentos.validade_autorizacao >= ('now'::text)::date)))))
          GROUP BY autorizacao.veiculo_placa, contrato.servico_nome, veiculo.numero_lugares, contrato.codigo, contrato.regiao_codigo) base
  GROUP BY base.regiao_codigo, base.servico_nome
  ORDER BY base.regiao_codigo, (sum(base.numero_lugares)) DESC, base.servico_nome;


ALTER TABLE fretamento.raiz_servico_lugares OWNER TO metroplan;

--
-- Name: rel_autorizacao; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.rel_autorizacao AS
 SELECT geral.formata_cnpj(empresa.cnpj) AS cnpj,
    empresa.nome AS contratada,
    geral.formata_processo(autorizacao.processo) AS processo,
    empresa.inscricao_estadual,
    to_char((veiculo.data_vencimento_seguro)::timestamp with time zone, 'DD/MM/YYYY'::text) AS data_vencimento_seguro,
    (contrato.codigo)::text AS contrato_codigo,
    contratante.nome AS contratante,
    contratante.municipio_nome AS municipio,
    contrato.servico_nome AS servico_contratado,
    autorizacao.codigo AS autorizacao_codigo,
    to_char(( SELECT d.d
           FROM ( SELECT veiculo.data_vencimento_seguro AS d
                UNION
                 SELECT contrato.data_fim AS d
                UNION
                 SELECT laudo_vistoria.data_validade AS d
                UNION
                 SELECT (autorizacao.data_inicio + '1 year'::interval) AS d) d
          ORDER BY d.d
         LIMIT 1), 'DD/MM/YYYY'::text) AS autorizacao_validade,
    to_char((laudo_vistoria.data_validade)::timestamp with time zone, 'DD/MM/YYYY'::text) AS laudo_validade,
    to_char(
        CASE
            WHEN (((autorizacao.data_inicio + '1 year'::interval) < contrato.data_fim) OR (true = true)) THEN (autorizacao.data_inicio + '1 year'::interval)
            ELSE (contrato.data_fim)::timestamp without time zone
        END, 'DD/MM/YYYY'::text) AS pagamento_vencimento,
    to_char((contrato.data_fim)::timestamp with time zone, 'DD/MM/YYYY'::text) AS contrato_vencimento,
    to_char((contrato.data_inicio)::timestamp with time zone, 'DD/MM/YYYY'::text) AS contrato_inicio,
    autorizacao.veiculo_placa AS placa,
    autorizacao.empresa_cnpj_sublocacao
   FROM fretamento.autorizacao,
    fretamento.contratante,
    fretamento.contrato,
    geral.empresa,
    fretamento.laudo_vistoria,
    geral.veiculo
  WHERE ((autorizacao.contrato_codigo = contrato.codigo) AND (contratante.codigo = contrato.contratante_codigo) AND (contrato.empresa_cnpj = empresa.cnpj) AND (laudo_vistoria.veiculo_placa = autorizacao.veiculo_placa) AND (veiculo.placa = autorizacao.veiculo_placa) AND ((veiculo.data_exclusao_fretamento IS NULL) OR (veiculo.data_exclusao_fretamento > (now() + '1 day'::interval))))
  ORDER BY laudo_vistoria.data_validade DESC, autorizacao.data_inicio DESC
 LIMIT 1;


ALTER TABLE fretamento.rel_autorizacao OWNER TO metroplan;

--
-- Name: relatorio_hlp; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.relatorio_hlp AS
 SELECT hlp.id,
    hlpa.autorizacao_codigo,
    (hlp.contrato_codigo)::text AS contrato_codigo,
    contrato.empresa_cnpj,
    hlp.sequencial,
    (hlp.ano)::text AS ano,
    empresa.nome AS empresa_nome,
    contratante.nome AS contratante_nome
   FROM fretamento.hlp,
    fretamento.hlpa,
    fretamento.contrato,
    geral.empresa,
    fretamento.contratante
  WHERE ((hlpa.hlp_id = hlp.id) AND (contrato.codigo = hlp.contrato_codigo) AND (empresa.cnpj = contrato.empresa_cnpj) AND (contratante.codigo = contrato.contratante_codigo));


ALTER TABLE fretamento.relatorio_hlp OWNER TO metroplan;

--
-- Name: seguradora; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.seguradora (
    nome text NOT NULL
);


ALTER TABLE fretamento.seguradora OWNER TO metroplan;

--
-- Name: servico; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.servico (
    nome text NOT NULL
);


ALTER TABLE fretamento.servico OWNER TO metroplan;

--
-- Name: todas_apolices; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.todas_apolices AS
 SELECT veiculo.placa,
    empresa.cnpj,
    veiculo.apolice,
    veiculo.seguradora,
    veiculo.data_vencimento_seguro,
    empresa.nome AS segurado
   FROM geral.veiculo,
    geral.empresa
  WHERE ((veiculo.apolice IS NOT NULL) AND (veiculo.empresa_cnpj = empresa.cnpj))
  ORDER BY veiculo.seguradora, empresa.nome;


ALTER TABLE fretamento.todas_apolices OWNER TO metroplan;

--
-- Name: veiculos_ok; Type: VIEW; Schema: fretamento; Owner: metroplan
--

CREATE VIEW fretamento.veiculos_ok AS
 SELECT DISTINCT raiz_contagem_vencimentos.placa,
    raiz_contagem_vencimentos.empresa_cnpj
   FROM fretamento.raiz_contagem_vencimentos
  WHERE ((raiz_contagem_vencimentos.validade_seguro >= ('now'::text)::date) AND (raiz_contagem_vencimentos.validade_contrato >= ('now'::text)::date) AND (raiz_contagem_vencimentos.validade_laudo >= ('now'::text)::date) AND (raiz_contagem_vencimentos.validade_autorizacao >= ('now'::text)::date) AND (raiz_contagem_vencimentos.autorizacao_renovacao = false) AND (raiz_contagem_vencimentos.laudo_renovacao = false));


ALTER TABLE fretamento.veiculos_ok OWNER TO metroplan;

--
-- Name: vencimento_seguradora; Type: TABLE; Schema: fretamento; Owner: metroplan
--

CREATE TABLE fretamento.vencimento_seguradora (
    id integer NOT NULL,
    placa text NOT NULL,
    vencimento date NOT NULL,
    insercao date DEFAULT ('now'::text)::date NOT NULL,
    apolice text NOT NULL,
    seguradora text NOT NULL,
    vencimento_metroplan date
);


ALTER TABLE fretamento.vencimento_seguradora OWNER TO metroplan;

--
-- Name: TABLE vencimento_seguradora; Type: COMMENT; Schema: fretamento; Owner: metroplan
--

COMMENT ON TABLE fretamento.vencimento_seguradora IS 'TODO: seguradora -> seguradora_nome';


--
-- Name: vencimento_seguradora_id_seq; Type: SEQUENCE; Schema: fretamento; Owner: metroplan
--

CREATE SEQUENCE fretamento.vencimento_seguradora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fretamento.vencimento_seguradora_id_seq OWNER TO metroplan;

--
-- Name: vencimento_seguradora_id_seq; Type: SEQUENCE OWNED BY; Schema: fretamento; Owner: metroplan
--

ALTER SEQUENCE fretamento.vencimento_seguradora_id_seq OWNED BY fretamento.vencimento_seguradora.id;


--
-- Name: acordo; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.acordo (
    codigo text NOT NULL,
    nome character varying NOT NULL
);


ALTER TABLE geral.acordo OWNER TO metroplan;

--
-- Name: acordo__empresa; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.acordo__empresa (
    acordo_codigo text NOT NULL,
    percentual_participacao numeric(5,2),
    empresa_codigo text NOT NULL
);


ALTER TABLE geral.acordo__empresa OWNER TO metroplan;

--
-- Name: classificacao_inmetro; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.classificacao_inmetro (
    nome text NOT NULL
);


ALTER TABLE geral.classificacao_inmetro OWNER TO metroplan;

--
-- Name: cor; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.cor (
    nome text NOT NULL
);
ALTER TABLE ONLY geral.cor ALTER COLUMN nome SET STATISTICS 0;


ALTER TABLE geral.cor OWNER TO metroplan;

--
-- Name: empresa_diretor; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.empresa_diretor (
    empresa_cnpj text NOT NULL,
    nome text NOT NULL,
    ordem integer NOT NULL
);


ALTER TABLE geral.empresa_diretor OWNER TO metroplan;

--
-- Name: engenheiro; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.engenheiro (
    nome text NOT NULL,
    oficina_nome text NOT NULL
);


ALTER TABLE geral.engenheiro OWNER TO metroplan;

--
-- Name: excluir_seguro; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.excluir_seguro (
    id integer NOT NULL,
    veiculo_placa text,
    data date DEFAULT ('now'::text)::date
);


ALTER TABLE geral.excluir_seguro OWNER TO metroplan;

--
-- Name: excluir_seguro_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.excluir_seguro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.excluir_seguro_id_seq OWNER TO metroplan;

--
-- Name: excluir_seguro_id_seq; Type: SEQUENCE OWNED BY; Schema: geral; Owner: metroplan
--

ALTER SEQUENCE geral.excluir_seguro_id_seq OWNED BY geral.excluir_seguro.id;


--
-- Name: feriado; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.feriado (
    id integer NOT NULL,
    data date,
    nome text
);


ALTER TABLE geral.feriado OWNER TO metroplan;

--
-- Name: feriado_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.feriado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.feriado_id_seq OWNER TO metroplan;

--
-- Name: feriado_id_seq; Type: SEQUENCE OWNED BY; Schema: geral; Owner: metroplan
--

ALTER SEQUENCE geral.feriado_id_seq OWNED BY geral.feriado.id;


--
-- Name: itl_vistoria; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.itl_vistoria (
    id integer NOT NULL,
    veiculo_placa text,
    data date,
    validade date,
    insercao timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE geral.itl_vistoria OWNER TO metroplan;

--
-- Name: itl_vistoria_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.itl_vistoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.itl_vistoria_id_seq OWNER TO metroplan;

--
-- Name: itl_vistoria_id_seq; Type: SEQUENCE OWNED BY; Schema: geral; Owner: metroplan
--

ALTER SEQUENCE geral.itl_vistoria_id_seq OWNED BY geral.itl_vistoria.id;


--
-- Name: logradouro_logradouro_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.logradouro_logradouro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.logradouro_logradouro_id_seq OWNER TO metroplan;

--
-- Name: logradouro; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.logradouro (
    logradouro_id integer DEFAULT nextval('geral.logradouro_logradouro_id_seq'::regclass) NOT NULL,
    nome text NOT NULL,
    municipio_nome text
);


ALTER TABLE geral.logradouro OWNER TO metroplan;

--
-- Name: metroplan; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.metroplan (
    id integer NOT NULL,
    diretor text NOT NULL,
    diretorio_documentos_fretamento text NOT NULL
);


ALTER TABLE geral.metroplan OWNER TO metroplan;

--
-- Name: metroplan_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.metroplan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.metroplan_id_seq OWNER TO metroplan;

--
-- Name: metroplan_id_seq; Type: SEQUENCE OWNED BY; Schema: geral; Owner: metroplan
--

ALTER SEQUENCE geral.metroplan_id_seq OWNED BY geral.metroplan.id;


--
-- Name: regiao; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.regiao (
    codigo text NOT NULL,
    nome character varying,
    ordem integer
);


ALTER TABLE geral.regiao OWNER TO metroplan;

--
-- Name: veiculo_vistoria; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_vistoria (
    veiculo_vistoria_id integer NOT NULL,
    veiculo_placa text,
    data date,
    data_vencimento date,
    processo text,
    engenheiro text,
    oficina text,
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE geral.veiculo_vistoria OWNER TO metroplan;

--
-- Name: COLUMN veiculo_vistoria.veiculo_placa; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo_vistoria.veiculo_placa IS 'criar constraint apos migracao';


--
-- Name: ultima_vistoria_veiculo; Type: VIEW; Schema: geral; Owner: metroplan
--

CREATE VIEW geral.ultima_vistoria_veiculo AS
 SELECT DISTINCT ON (veiculo_vistoria.veiculo_placa) veiculo_vistoria.veiculo_placa,
    veiculo_vistoria.data,
    veiculo_vistoria.data_vencimento
   FROM geral.veiculo_vistoria
  ORDER BY veiculo_vistoria.veiculo_placa, veiculo_vistoria.data_vencimento DESC;


ALTER TABLE geral.ultima_vistoria_veiculo OWNER TO metroplan;

--
-- Name: validador_be; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.validador_be (
    numero text NOT NULL
);


ALTER TABLE geral.validador_be OWNER TO metroplan;

--
-- Name: veiculo_alteracao; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_alteracao (
    veiculo_alteracao_id integer NOT NULL,
    veiculo_placa text,
    numero text NOT NULL,
    data date,
    processo text,
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE geral.veiculo_alteracao OWNER TO metroplan;

--
-- Name: COLUMN veiculo_alteracao.veiculo_placa; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo_alteracao.veiculo_placa IS 'criar constraint apos migracao';


--
-- Name: veiculo_alteracao_veiculo_alteracao_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.veiculo_alteracao_veiculo_alteracao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.veiculo_alteracao_veiculo_alteracao_id_seq OWNER TO metroplan;

--
-- Name: veiculo_alteracao_veiculo_alteracao_id_seq; Type: SEQUENCE OWNED BY; Schema: geral; Owner: metroplan
--

ALTER SEQUENCE geral.veiculo_alteracao_veiculo_alteracao_id_seq OWNED BY geral.veiculo_alteracao.veiculo_alteracao_id;


--
-- Name: veiculo_carroceria; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_carroceria (
    nome text NOT NULL,
    migra_codigo character varying
);


ALTER TABLE geral.veiculo_carroceria OWNER TO metroplan;

--
-- Name: veiculo_chassi; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_chassi (
    nome text NOT NULL,
    migra_codigo character varying
);


ALTER TABLE geral.veiculo_chassi OWNER TO metroplan;

--
-- Name: veiculo_combustivel; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_combustivel (
    nome text NOT NULL
);


ALTER TABLE geral.veiculo_combustivel OWNER TO metroplan;

--
-- Name: veiculo_declaracao; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_declaracao (
    veiculo_declaracao_id integer NOT NULL,
    veiculo_placa text,
    numero text NOT NULL,
    data date,
    processo text,
    CONSTRAINT processo_length_chk CHECK ((length(processo) = 11))
);


ALTER TABLE geral.veiculo_declaracao OWNER TO metroplan;

--
-- Name: COLUMN veiculo_declaracao.veiculo_placa; Type: COMMENT; Schema: geral; Owner: metroplan
--

COMMENT ON COLUMN geral.veiculo_declaracao.veiculo_placa IS 'criar constraint apos migracao';


--
-- Name: veiculo_declaracao_veiculo_declaracao_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.veiculo_declaracao_veiculo_declaracao_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.veiculo_declaracao_veiculo_declaracao_id_seq OWNER TO metroplan;

--
-- Name: veiculo_declaracao_veiculo_declaracao_id_seq; Type: SEQUENCE OWNED BY; Schema: geral; Owner: metroplan
--

ALTER SEQUENCE geral.veiculo_declaracao_veiculo_declaracao_id_seq OWNED BY geral.veiculo_declaracao.veiculo_declaracao_id;


--
-- Name: veiculo_modelo; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_modelo (
    nome text NOT NULL
);


ALTER TABLE geral.veiculo_modelo OWNER TO metroplan;

--
-- Name: veiculo_motor; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_motor (
    nome text NOT NULL
);


ALTER TABLE geral.veiculo_motor OWNER TO metroplan;

--
-- Name: veiculo_qualidade; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_qualidade (
    nome text NOT NULL
);


ALTER TABLE geral.veiculo_qualidade OWNER TO metroplan;

--
-- Name: veiculo_rodados; Type: TABLE; Schema: geral; Owner: metroplan
--

CREATE TABLE geral.veiculo_rodados (
    nome text NOT NULL
);


ALTER TABLE geral.veiculo_rodados OWNER TO metroplan;

--
-- Name: veiculo_vistoria_veiculo_vistoria_id_seq; Type: SEQUENCE; Schema: geral; Owner: metroplan
--

CREATE SEQUENCE geral.veiculo_vistoria_veiculo_vistoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE geral.veiculo_vistoria_veiculo_vistoria_id_seq OWNER TO metroplan;

--
-- Name: veiculo_vistoria_veiculo_vistoria_id_seq; Type: SEQUENCE OWNED BY; Schema: geral; Owner: metroplan
--

ALTER SEQUENCE geral.veiculo_vistoria_veiculo_vistoria_id_seq OWNED BY geral.veiculo_vistoria.veiculo_vistoria_id;


--
-- Name: veiculos_empresas; Type: VIEW; Schema: geral; Owner: metroplan
--

CREATE VIEW geral.veiculos_empresas AS
 SELECT empresa.cnpj,
    veiculo.placa,
    empresa_codigo.codigo,
    empresa.nome,
    empresa.nome_simplificado,
    veiculo.prefixo
   FROM ((geral.veiculo
     LEFT JOIN geral.empresa ON ((veiculo.empresa_cnpj = empresa.cnpj)))
     LEFT JOIN geral.empresa_codigo ON ((empresa_codigo.codigo = veiculo.empresa_codigo_codigo)));


ALTER TABLE geral.veiculos_empresas OWNER TO metroplan;

--
-- Name: veiculos_padrao; Type: VIEW; Schema: geral; Owner: metroplan
--

CREATE VIEW geral.veiculos_padrao AS
 SELECT veiculo.placa,
    veiculo.chassi_ano,
    veiculo.data_inclusao_concessao,
    veiculo.data_exclusao_concessao,
    empresa_codigo.regiao_codigo
   FROM geral.veiculo,
    geral.empresa_codigo,
    geral.empresa
  WHERE ((veiculo.classificacao_inmetro_nome = 'URBANO'::text) AND (veiculo.data_inclusao_concessao IS NOT NULL) AND ((veiculo.data_exclusao_concessao IS NULL) OR (veiculo.data_exclusao_concessao > ('now'::text)::date)) AND (veiculo.empresa_codigo_codigo = empresa_codigo.codigo) AND (empresa_codigo.empresa_cnpj = empresa.cnpj) AND ((empresa.data_exclusao IS NULL) OR (empresa.data_exclusao > ('now'::text)::date)) AND (veiculo.chassi_ano >= 1999) AND (veiculo.acordo_codigo IS NULL));


ALTER TABLE geral.veiculos_padrao OWNER TO metroplan;

--
-- Name: rota; Type: TABLE; Schema: gm; Owner: metroplan
--

CREATE TABLE gm.rota (
    id integer NOT NULL,
    linha_codigo text NOT NULL,
    rota path NOT NULL,
    ida boolean NOT NULL
);


ALTER TABLE gm.rota OWNER TO metroplan;

--
-- Name: rota_id_seq; Type: SEQUENCE; Schema: gm; Owner: metroplan
--

CREATE SEQUENCE gm.rota_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gm.rota_id_seq OWNER TO metroplan;

--
-- Name: rota_id_seq; Type: SEQUENCE OWNED BY; Schema: gm; Owner: metroplan
--

ALTER SEQUENCE gm.rota_id_seq OWNED BY gm.rota.id;


--
-- Name: admin; Type: TABLE; Schema: motorista; Owner: metroplan
--

CREATE TABLE motorista.admin (
    cpf text NOT NULL,
    senha text,
    email text
);


ALTER TABLE motorista.admin OWNER TO metroplan;

--
-- Name: empresa; Type: TABLE; Schema: motorista; Owner: metroplan
--

CREATE TABLE motorista.empresa (
    cnpj text NOT NULL,
    razao_social text,
    endereco text,
    cidade text,
    estado text,
    cep text,
    email text,
    telefone text
);


ALTER TABLE motorista.empresa OWNER TO metroplan;

--
-- Name: motorista; Type: TABLE; Schema: motorista; Owner: metroplan
--

CREATE TABLE motorista.motorista (
    cnh text NOT NULL,
    categoria_cnh text,
    validade_cnh date,
    nome text,
    rg text,
    cpf text NOT NULL,
    empresa_cnpj text
);


ALTER TABLE motorista.motorista OWNER TO metroplan;

--
-- Name: usuario; Type: TABLE; Schema: motorista; Owner: metroplan
--

CREATE TABLE motorista.usuario (
    cpf text NOT NULL,
    nome text,
    email text,
    telefone text,
    senha text,
    empresa_cnpj text
);


ALTER TABLE motorista.usuario OWNER TO metroplan;

--
-- Name: COLUMN usuario.telefone; Type: COMMENT; Schema: motorista; Owner: metroplan
--

COMMENT ON COLUMN motorista.usuario.telefone IS '
';


--
-- Name: auto; Type: TABLE; Schema: multas; Owner: metroplan
--

CREATE TABLE multas.auto (
    codigo text DEFAULT multas.proximo_codigo_auto() NOT NULL,
    linha_codigo text,
    data_infracao date,
    data_emissao date,
    fiscal_matricula text,
    numero_notificacao integer,
    observacoes text,
    veiculo_placa text,
    resolucao_cetm text,
    valor text,
    endereco_infracao text,
    municipio_nome_infracao text,
    decreto text,
    empresa_cnpj text,
    processo text,
    data_abertura date,
    data_entrada_cft date,
    valor_boleto text,
    data_vencimento_boleto date,
    numero_ar text,
    data_recebimento_ar date,
    data_entrada_ra date,
    data_resposta_ra date,
    data_recebimento_ar_resposta_ra date,
    data_entrada_recurso_cetm date,
    data_deferimento_recurso_cetm date,
    valor_pago text,
    data_pagamento date,
    valor_principal text,
    valor_juros text,
    data_saida_cft date,
    descricao text,
    penalidade_subgrupo text,
    migracao text,
    hora_infracao time without time zone,
    ra_deferido boolean,
    sentido text,
    CONSTRAINT auto_codigo_len_chk CHECK (((length(codigo) = 6) OR (length(codigo) = 7))),
    CONSTRAINT processo_length_check CHECK (((length(processo) = 0) OR (length(processo) = 11)))
);


ALTER TABLE multas.auto OWNER TO metroplan;

--
-- Name: COLUMN auto.migracao; Type: COMMENT; Schema: multas; Owner: metroplan
--

COMMENT ON COLUMN multas.auto.migracao IS 'corrigir após migração';


--
-- Name: carro; Type: TABLE; Schema: multas; Owner: metroplan
--

CREATE TABLE multas.carro (
    placa text NOT NULL,
    infrator_cnpj_cpf text,
    tipo text,
    prefixo text
);


ALTER TABLE multas.carro OWNER TO metroplan;

--
-- Name: devedor; Type: TABLE; Schema: multas; Owner: metroplan
--

CREATE TABLE multas.devedor (
    id integer NOT NULL,
    empresa_cnpj text NOT NULL,
    processo text NOT NULL,
    data_vencimento date NOT NULL,
    valor_historico numeric(12,2) NOT NULL,
    data_pagamento date,
    baixa_divida boolean NOT NULL,
    CONSTRAINT devedor_processo_chk CHECK ((length(processo) = 11))
);


ALTER TABLE multas.devedor OWNER TO metroplan;

--
-- Name: devedor_id_seq; Type: SEQUENCE; Schema: multas; Owner: metroplan
--

CREATE SEQUENCE multas.devedor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE multas.devedor_id_seq OWNER TO metroplan;

--
-- Name: devedor_id_seq; Type: SEQUENCE OWNED BY; Schema: multas; Owner: metroplan
--

ALTER SEQUENCE multas.devedor_id_seq OWNED BY multas.devedor.id;


--
-- Name: fiscal; Type: TABLE; Schema: multas; Owner: metroplan
--

CREATE TABLE multas.fiscal (
    matricula text NOT NULL,
    nome text,
    ativo boolean DEFAULT true NOT NULL
);


ALTER TABLE multas.fiscal OWNER TO metroplan;

--
-- Name: infrator; Type: TABLE; Schema: multas; Owner: metroplan
--

CREATE TABLE multas.infrator (
    cnpj_cpf text NOT NULL,
    nome text,
    endereco text,
    cep text,
    telefone text,
    email text,
    municipio text,
    regiao text,
    registro text,
    concessionaria boolean
);


ALTER TABLE multas.infrator OWNER TO metroplan;

--
-- Name: COLUMN infrator.registro; Type: COMMENT; Schema: multas; Owner: metroplan
--

COMMENT ON COLUMN multas.infrator.registro IS 'a ser deletado apos migracao';


--
-- Name: municipio; Type: TABLE; Schema: multas; Owner: metroplan
--

CREATE TABLE multas.municipio (
    codigo text NOT NULL,
    nome text NOT NULL
);


ALTER TABLE multas.municipio OWNER TO metroplan;

--
-- Name: penalidade; Type: TABLE; Schema: multas; Owner: metroplan
--

CREATE TABLE multas.penalidade (
    subgrupo text NOT NULL,
    grupo text,
    descricao text,
    valor numeric
);


ALTER TABLE multas.penalidade OWNER TO metroplan;

--
-- Name: penalidade_combo; Type: VIEW; Schema: multas; Owner: metroplan
--

CREATE VIEW multas.penalidade_combo AS
 SELECT penalidade.subgrupo,
    penalidade.grupo,
    penalidade.descricao
   FROM multas.penalidade;


ALTER TABLE multas.penalidade_combo OWNER TO metroplan;

--
-- Name: andamento; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.andamento (
    id integer NOT NULL,
    data timestamp without time zone,
    resposta text,
    notas text,
    departamento_nome text,
    empresa_codigo text,
    ocorrencia_id integer,
    ocorrencia_prioridade_nome text,
    ocorrencia_situacao_nome text
);


ALTER TABLE saac.andamento OWNER TO metroplan;

--
-- Name: andamento_id_seq; Type: SEQUENCE; Schema: saac; Owner: metroplan
--

CREATE SEQUENCE saac.andamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE saac.andamento_id_seq OWNER TO metroplan;

--
-- Name: andamento_id_seq; Type: SEQUENCE OWNED BY; Schema: saac; Owner: metroplan
--

ALTER SEQUENCE saac.andamento_id_seq OWNED BY saac.andamento.id;


--
-- Name: departamento; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.departamento (
    nome text NOT NULL
);


ALTER TABLE saac.departamento OWNER TO metroplan;

--
-- Name: ocorrencia; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia (
    ocorrencia_id integer NOT NULL,
    ocorrencia_tipo_nome text NOT NULL,
    ocorrencia_servico_nome text,
    ocorrencia_assunto_nome text NOT NULL,
    veiculo_placa text,
    veiculo_prefixo integer,
    linha_codigo text,
    local_ocorrencia text,
    municipio_nome_ocorrencia text,
    data_ocorrencia timestamp(0) without time zone,
    nome_reclamante text,
    telefone_reclamante text,
    data_atendimento timestamp(0) without time zone DEFAULT now(),
    descricao text,
    atendente text,
    empresa_codigo text,
    bairro_id_ocorrencia integer,
    bairro_id_reclamante integer,
    localidade_id_ocorrencia integer,
    localidade_id_reclamante integer,
    data_fechamento date,
    email_reclamante text,
    ocorrencia_canal_nome text,
    ocorrencia_prioridade_nome text,
    idade integer
);


ALTER TABLE saac.ocorrencia OWNER TO metroplan;

--
-- Name: COLUMN ocorrencia.veiculo_prefixo; Type: COMMENT; Schema: saac; Owner: metroplan
--

COMMENT ON COLUMN saac.ocorrencia.veiculo_prefixo IS 'Não pode ser fkey até ser unique em veiculo';


--
-- Name: COLUMN ocorrencia.bairro_id_ocorrencia; Type: COMMENT; Schema: saac; Owner: metroplan
--

COMMENT ON COLUMN saac.ocorrencia.bairro_id_ocorrencia IS 'nao está sendo usado';


--
-- Name: COLUMN ocorrencia.bairro_id_reclamante; Type: COMMENT; Schema: saac; Owner: metroplan
--

COMMENT ON COLUMN saac.ocorrencia.bairro_id_reclamante IS 'nao está sendo usado';


--
-- Name: COLUMN ocorrencia.localidade_id_ocorrencia; Type: COMMENT; Schema: saac; Owner: metroplan
--

COMMENT ON COLUMN saac.ocorrencia.localidade_id_ocorrencia IS 'não está sendo usado';


--
-- Name: COLUMN ocorrencia.localidade_id_reclamante; Type: COMMENT; Schema: saac; Owner: metroplan
--

COMMENT ON COLUMN saac.ocorrencia.localidade_id_reclamante IS 'nao está sendo usado';


--
-- Name: ocorrencia_assunto; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia_assunto (
    nome text NOT NULL,
    ocorrencia_assunto_tipo_nome text,
    id integer NOT NULL
);


ALTER TABLE saac.ocorrencia_assunto OWNER TO metroplan;

--
-- Name: ocorrencia_assunto_id_seq; Type: SEQUENCE; Schema: saac; Owner: metroplan
--

CREATE SEQUENCE saac.ocorrencia_assunto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE saac.ocorrencia_assunto_id_seq OWNER TO metroplan;

--
-- Name: ocorrencia_assunto_id_seq; Type: SEQUENCE OWNED BY; Schema: saac; Owner: metroplan
--

ALTER SEQUENCE saac.ocorrencia_assunto_id_seq OWNED BY saac.ocorrencia_assunto.id;


--
-- Name: ocorrencia_assunto_tipo; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia_assunto_tipo (
    nome text NOT NULL
);


ALTER TABLE saac.ocorrencia_assunto_tipo OWNER TO metroplan;

--
-- Name: ocorrencia_canal; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia_canal (
    nome text NOT NULL
);


ALTER TABLE saac.ocorrencia_canal OWNER TO metroplan;

--
-- Name: ocorrencia_ocorrencia_id_seq; Type: SEQUENCE; Schema: saac; Owner: metroplan
--

CREATE SEQUENCE saac.ocorrencia_ocorrencia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE saac.ocorrencia_ocorrencia_id_seq OWNER TO metroplan;

--
-- Name: ocorrencia_ocorrencia_id_seq; Type: SEQUENCE OWNED BY; Schema: saac; Owner: metroplan
--

ALTER SEQUENCE saac.ocorrencia_ocorrencia_id_seq OWNED BY saac.ocorrencia.ocorrencia_id;


--
-- Name: ocorrencia_prioridade; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia_prioridade (
    nome text NOT NULL
);


ALTER TABLE saac.ocorrencia_prioridade OWNER TO metroplan;

--
-- Name: ocorrencia_servico; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia_servico (
    nome text NOT NULL
);


ALTER TABLE saac.ocorrencia_servico OWNER TO metroplan;

--
-- Name: ocorrencia_situacao; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia_situacao (
    nome text NOT NULL
);


ALTER TABLE saac.ocorrencia_situacao OWNER TO metroplan;

--
-- Name: ocorrencia_tipo; Type: TABLE; Schema: saac; Owner: metroplan
--

CREATE TABLE saac.ocorrencia_tipo (
    nome text NOT NULL
);


ALTER TABLE saac.ocorrencia_tipo OWNER TO metroplan;

--
-- Name: tipos_ocorrrencia; Type: VIEW; Schema: saac; Owner: metroplan
--

CREATE VIEW saac.tipos_ocorrrencia AS
 SELECT ((ocorrencia_assunto.ocorrencia_assunto_tipo_nome || ': '::text) || ocorrencia_assunto.nome) AS "?column?"
   FROM saac.ocorrencia_assunto
  ORDER BY ocorrencia_assunto.ocorrencia_assunto_tipo_nome, ocorrencia_assunto.nome;


ALTER TABLE saac.tipos_ocorrrencia OWNER TO metroplan;

--
-- Name: auto; Type: TABLE; Schema: temp; Owner: metroplan
--

CREATE TABLE temp.auto (
    id integer NOT NULL,
    codigo text,
    cnpj text,
    linha text,
    ignorar_nome_linha text,
    sentido text,
    horario text,
    placa text,
    ignorar_tipo_veiculo text,
    ignorar_prefixo text,
    notificacao text,
    sub_grupo text,
    grupo text,
    valor text,
    base_legal_decreto text,
    base_legal_resolucao_cetm text,
    local text,
    municipio text,
    data_infracao text,
    data_emissao text,
    hora_infracao text,
    obs text,
    matricula_fiscal text,
    nome_fiscal text,
    ra_deferido boolean
);


ALTER TABLE temp.auto OWNER TO metroplan;

--
-- Name: auto_id_seq; Type: SEQUENCE; Schema: temp; Owner: metroplan
--

CREATE SEQUENCE temp.auto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE temp.auto_id_seq OWNER TO metroplan;

--
-- Name: auto_id_seq; Type: SEQUENCE OWNED BY; Schema: temp; Owner: metroplan
--

ALTER SEQUENCE temp.auto_id_seq OWNED BY temp.auto.id;


--
-- Name: fiscal; Type: TABLE; Schema: temp; Owner: metroplan
--

CREATE TABLE temp.fiscal (
    codigo text NOT NULL,
    nome text,
    ativo boolean
);


ALTER TABLE temp.fiscal OWNER TO metroplan;

--
-- Name: multa; Type: TABLE; Schema: temp; Owner: metroplan
--

CREATE TABLE temp.multa (
    id integer NOT NULL,
    codigo text,
    processo text,
    empresa text,
    abertura text,
    entrada_cft text,
    ar text,
    ar_recebida text,
    data_ar text,
    recurso_adm text,
    data_recurso_adm text,
    recurso_adm_deferido text,
    data_resposta_recurso_adm text,
    data_recebimento_ar_recurso_adm text,
    recurso_cetm text,
    data_recurso_ctem text,
    recurso_ctem_deferido text,
    data_deferimento_recurso_adm text,
    guia_arrecadacao text,
    data_ar_protocolo_ctem text,
    valor_boleto text,
    data_vencimento_boleto text,
    valor_pago text,
    data_pagamento text,
    valor_principal text,
    valor_juros text,
    data_saida_cft text,
    obs text,
    entrada_ra text,
    ra_deferido boolean
);


ALTER TABLE temp.multa OWNER TO metroplan;

--
-- Name: multa_id_seq; Type: SEQUENCE; Schema: temp; Owner: metroplan
--

CREATE SEQUENCE temp.multa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE temp.multa_id_seq OWNER TO metroplan;

--
-- Name: multa_id_seq; Type: SEQUENCE OWNED BY; Schema: temp; Owner: metroplan
--

ALTER SEQUENCE temp.multa_id_seq OWNED BY temp.multa.id;


--
-- Name: municipio; Type: TABLE; Schema: temp; Owner: metroplan
--

CREATE TABLE temp.municipio (
    codigo text NOT NULL,
    nome text
);


ALTER TABLE temp.municipio OWNER TO metroplan;

--
-- Name: penalidade; Type: TABLE; Schema: temp; Owner: metroplan
--

CREATE TABLE temp.penalidade (
    subgrupo text NOT NULL,
    grupo text,
    descricao text,
    valor text
);


ALTER TABLE temp.penalidade OWNER TO metroplan;

--
-- Name: papel; Type: TABLE; Schema: web; Owner: postgres
--

CREATE TABLE web.papel (
    nome text NOT NULL
);


ALTER TABLE web.papel OWNER TO postgres;

--
-- Name: token_validacao_email; Type: TABLE; Schema: web; Owner: postgres
--

CREATE TABLE web.token_validacao_email (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    token text NOT NULL,
    criado_em timestamp without time zone DEFAULT now() NOT NULL,
    expira_em timestamp without time zone NOT NULL
);


ALTER TABLE web.token_validacao_email OWNER TO postgres;

--
-- Name: token_validacao_email_id_seq; Type: SEQUENCE; Schema: web; Owner: postgres
--

CREATE SEQUENCE web.token_validacao_email_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE web.token_validacao_email_id_seq OWNER TO postgres;

--
-- Name: token_validacao_email_id_seq; Type: SEQUENCE OWNED BY; Schema: web; Owner: postgres
--

ALTER SEQUENCE web.token_validacao_email_id_seq OWNED BY web.token_validacao_email.id;


--
-- Name: usuario; Type: TABLE; Schema: web; Owner: postgres
--

CREATE TABLE web.usuario (
    id integer NOT NULL,
    papel_nome text NOT NULL,
    email text NOT NULL,
    nome text NOT NULL,
    cpf text,
    data_nascimento date,
    telefone text,
    senha text,
    empresa_cnpj text,
    criado_em timestamp without time zone DEFAULT now(),
    atualizado_em timestamp without time zone DEFAULT now(),
    ativo boolean DEFAULT true NOT NULL,
    email_validado boolean DEFAULT false NOT NULL
);


ALTER TABLE web.usuario OWNER TO postgres;

--
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: web; Owner: postgres
--

CREATE SEQUENCE web.usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE web.usuario_id_seq OWNER TO postgres;

--
-- Name: usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: web; Owner: postgres
--

ALTER SEQUENCE web.usuario_id_seq OWNED BY web.usuario.id;


--
-- Name: log id; Type: DEFAULT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.log ALTER COLUMN id SET DEFAULT nextval('admin.log_id_seq'::regclass);


--
-- Name: usuario_permissao permissao_id; Type: DEFAULT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.usuario_permissao ALTER COLUMN permissao_id SET DEFAULT nextval('admin.usuario_permissao_permissao_id_seq'::regclass);


--
-- Name: denuncia id; Type: DEFAULT; Schema: app; Owner: metroplan
--

ALTER TABLE ONLY app.denuncia ALTER COLUMN id SET DEFAULT nextval('app.denuncia_id_seq'::regclass);


--
-- Name: log_acesso id; Type: DEFAULT; Schema: app; Owner: metroplan
--

ALTER TABLE ONLY app.log_acesso ALTER COLUMN id SET DEFAULT nextval('app.log_acesso_id_seq'::regclass);


--
-- Name: log_http id; Type: DEFAULT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.log_http ALTER COLUMN id SET DEFAULT nextval('app.log_http_id_seq1'::regclass);


--
-- Name: declaracao id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.declaracao ALTER COLUMN id SET DEFAULT nextval('concessao.declaracao_id_seq'::regclass);


--
-- Name: horario horario_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario ALTER COLUMN horario_id SET DEFAULT nextval('concessao.horario_horario_id_seq'::regclass);


--
-- Name: horario_hidroviario horario_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario_hidroviario ALTER COLUMN horario_id SET DEFAULT nextval('concessao.horario_hidroviario_horario_id_seq'::regclass);


--
-- Name: horario_verao horario_verao_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario_verao ALTER COLUMN horario_verao_id SET DEFAULT nextval('concessao.horario_verao_hvid_seq'::regclass);


--
-- Name: itinerario itinerario_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario ALTER COLUMN itinerario_id SET DEFAULT nextval('concessao.itinerario_itinerario_id_seq'::regclass);


--
-- Name: itinerario_hidroviario itinerario_hidroviario_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_hidroviario ALTER COLUMN itinerario_hidroviario_id SET DEFAULT nextval('concessao.itinerario_hidroviario_itinerario_hidroviario_id_seq'::regclass);


--
-- Name: itinerario_verao itinerario_verao_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_verao ALTER COLUMN itinerario_verao_id SET DEFAULT nextval('concessao.itinerario_verao_ivid_seq'::regclass);


--
-- Name: linha id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha ALTER COLUMN id SET DEFAULT nextval('concessao.linha_id_seq'::regclass);


--
-- Name: linha_historico id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_historico ALTER COLUMN id SET DEFAULT nextval('concessao.linha_historico_id_seq'::regclass);


--
-- Name: mostra_verao id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.mostra_verao ALTER COLUMN id SET DEFAULT nextval('concessao.mostra_verao_id_seq'::regclass);


--
-- Name: ordem_servico__linha ordem_servico__linha_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico__linha ALTER COLUMN ordem_servico__linha_id SET DEFAULT nextval('concessao.ordem_servico__linha_ordem_servico__linha_id_seq'::regclass);


--
-- Name: ordem_servico_hidroviario__linha_hidroviario ordem_servico_hidroviario__linha_hidroviario_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico_hidroviario__linha_hidroviario ALTER COLUMN ordem_servico_hidroviario__linha_hidroviario_id SET DEFAULT nextval('concessao.ordem_servico_hidroviario__li_ordem_servico_hidroviario__li_seq'::regclass);


--
-- Name: secao_tarifaria secao_tarifaria_id; Type: DEFAULT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.secao_tarifaria ALTER COLUMN secao_tarifaria_id SET DEFAULT nextval('concessao.secao_tarifaria_secao_tarifaria_id_seq'::regclass);


--
-- Name: documento id; Type: DEFAULT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento ALTER COLUMN id SET DEFAULT nextval('eventual.documento_id_seq'::regclass);


--
-- Name: documento_motorista id; Type: DEFAULT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_motorista ALTER COLUMN id SET DEFAULT nextval('eventual.documento_motorista_id_seq'::regclass);


--
-- Name: fluxo_pendencia id; Type: DEFAULT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.fluxo_pendencia ALTER COLUMN id SET DEFAULT nextval('eventual.fluxo_pendencia_id_seq'::regclass);


--
-- Name: motorista id; Type: DEFAULT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.motorista ALTER COLUMN id SET DEFAULT nextval('eventual.motorista_id_seq'::regclass);


--
-- Name: passageiro id; Type: DEFAULT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.passageiro ALTER COLUMN id SET DEFAULT nextval('eventual.passageiro_id_seq'::regclass);


--
-- Name: viagem id; Type: DEFAULT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem ALTER COLUMN id SET DEFAULT nextval('eventual.viagem_id_seq'::regclass);


--
-- Name: autorizacao_emitida autorizacao_emitida_id; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao_emitida ALTER COLUMN autorizacao_emitida_id SET DEFAULT nextval('fretamento.autorizacao_emitida_autorizacao_emitida_id_seq'::regclass);


--
-- Name: contrato codigo; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato ALTER COLUMN codigo SET DEFAULT nextval('fretamento.contrato_contrato_codigo_seq'::regclass);


--
-- Name: contrato_itinerario itinerario_id; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato_itinerario ALTER COLUMN itinerario_id SET DEFAULT nextval('fretamento.contrato_itinerario_itinerario_id_seq'::regclass);


--
-- Name: guia id; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.guia ALTER COLUMN id SET DEFAULT nextval('fretamento.guia_id_seq'::regclass);


--
-- Name: historico id; Type: DEFAULT; Schema: fretamento; Owner: postgres
--

ALTER TABLE ONLY fretamento.historico ALTER COLUMN id SET DEFAULT nextval('fretamento.historico_id_seq1'::regclass);


--
-- Name: hlp id; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.hlp ALTER COLUMN id SET DEFAULT nextval('fretamento.hlp_id_seq'::regclass);


--
-- Name: hlpa hlpa_id; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.hlpa ALTER COLUMN hlpa_id SET DEFAULT nextval('fretamento.hlpa_hlpa_id_seq'::regclass);


--
-- Name: laudo_vistoria laudo_vistoria_id; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.laudo_vistoria ALTER COLUMN laudo_vistoria_id SET DEFAULT nextval('fretamento.laudo_vistoria_laudo_vistoria_id_seq'::regclass);


--
-- Name: vencimento_seguradora id; Type: DEFAULT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.vencimento_seguradora ALTER COLUMN id SET DEFAULT nextval('fretamento.vencimento_seguradora_id_seq'::regclass);


--
-- Name: excluir_seguro id; Type: DEFAULT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.excluir_seguro ALTER COLUMN id SET DEFAULT nextval('geral.excluir_seguro_id_seq'::regclass);


--
-- Name: feriado id; Type: DEFAULT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.feriado ALTER COLUMN id SET DEFAULT nextval('geral.feriado_id_seq'::regclass);


--
-- Name: itl_vistoria id; Type: DEFAULT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.itl_vistoria ALTER COLUMN id SET DEFAULT nextval('geral.itl_vistoria_id_seq'::regclass);


--
-- Name: metroplan id; Type: DEFAULT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.metroplan ALTER COLUMN id SET DEFAULT nextval('geral.metroplan_id_seq'::regclass);


--
-- Name: veiculo_alteracao veiculo_alteracao_id; Type: DEFAULT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_alteracao ALTER COLUMN veiculo_alteracao_id SET DEFAULT nextval('geral.veiculo_alteracao_veiculo_alteracao_id_seq'::regclass);


--
-- Name: veiculo_declaracao veiculo_declaracao_id; Type: DEFAULT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_declaracao ALTER COLUMN veiculo_declaracao_id SET DEFAULT nextval('geral.veiculo_declaracao_veiculo_declaracao_id_seq'::regclass);


--
-- Name: veiculo_vistoria veiculo_vistoria_id; Type: DEFAULT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_vistoria ALTER COLUMN veiculo_vistoria_id SET DEFAULT nextval('geral.veiculo_vistoria_veiculo_vistoria_id_seq'::regclass);


--
-- Name: rota id; Type: DEFAULT; Schema: gm; Owner: metroplan
--

ALTER TABLE ONLY gm.rota ALTER COLUMN id SET DEFAULT nextval('gm.rota_id_seq'::regclass);


--
-- Name: devedor id; Type: DEFAULT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.devedor ALTER COLUMN id SET DEFAULT nextval('multas.devedor_id_seq'::regclass);


--
-- Name: andamento id; Type: DEFAULT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.andamento ALTER COLUMN id SET DEFAULT nextval('saac.andamento_id_seq'::regclass);


--
-- Name: ocorrencia ocorrencia_id; Type: DEFAULT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia ALTER COLUMN ocorrencia_id SET DEFAULT nextval('saac.ocorrencia_ocorrencia_id_seq'::regclass);


--
-- Name: ocorrencia_assunto id; Type: DEFAULT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_assunto ALTER COLUMN id SET DEFAULT nextval('saac.ocorrencia_assunto_id_seq'::regclass);


--
-- Name: auto id; Type: DEFAULT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.auto ALTER COLUMN id SET DEFAULT nextval('temp.auto_id_seq'::regclass);


--
-- Name: multa id; Type: DEFAULT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.multa ALTER COLUMN id SET DEFAULT nextval('temp.multa_id_seq'::regclass);


--
-- Name: token_validacao_email id; Type: DEFAULT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.token_validacao_email ALTER COLUMN id SET DEFAULT nextval('web.token_validacao_email_id_seq'::regclass);


--
-- Name: usuario id; Type: DEFAULT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.usuario ALTER COLUMN id SET DEFAULT nextval('web.usuario_id_seq'::regclass);


--
-- Name: log admin_log_id_pk; Type: CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.log
    ADD CONSTRAINT admin_log_id_pk PRIMARY KEY (id);


--
-- Name: versao admin_versao_pk; Type: CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.versao
    ADD CONSTRAINT admin_versao_pk PRIMARY KEY (data);


--
-- Name: permissao permissao_pkey; Type: CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.permissao
    ADD CONSTRAINT permissao_pkey PRIMARY KEY (nome);


--
-- Name: usuario usuario_nome_pkey; Type: CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.usuario
    ADD CONSTRAINT usuario_nome_pkey PRIMARY KEY (nome);


--
-- Name: usuario_permissao usuario_permissao_id_pkey; Type: CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.usuario_permissao
    ADD CONSTRAINT usuario_permissao_id_pkey PRIMARY KEY (permissao_id);


--
-- Name: usuario_permissao usuario_permissao_unique; Type: CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.usuario_permissao
    ADD CONSTRAINT usuario_permissao_unique UNIQUE (usuario_nome, permissao_nome);


--
-- Name: log_acesso app_log_acesso_pk; Type: CONSTRAINT; Schema: app; Owner: metroplan
--

ALTER TABLE ONLY app.log_acesso
    ADD CONSTRAINT app_log_acesso_pk PRIMARY KEY (id);


--
-- Name: denuncia denuncia_id_pk; Type: CONSTRAINT; Schema: app; Owner: metroplan
--

ALTER TABLE ONLY app.denuncia
    ADD CONSTRAINT denuncia_id_pk PRIMARY KEY (id);


--
-- Name: log_http http_acesso_id_pk; Type: CONSTRAINT; Schema: app; Owner: postgres
--

ALTER TABLE ONLY app.log_http
    ADD CONSTRAINT http_acesso_id_pk PRIMARY KEY (id);


--
-- Name: bod_arquivo bod_arquivo_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.bod_arquivo
    ADD CONSTRAINT bod_arquivo_pkey PRIMARY KEY (bod_arquivo_id);


--
-- Name: bod bod_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.bod
    ADD CONSTRAINT bod_pkey PRIMARY KEY (bod_id);


--
-- Name: empresa_codigo_hidroviario codigo_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.empresa_codigo_hidroviario
    ADD CONSTRAINT codigo_pkey PRIMARY KEY (codigo);


--
-- Name: concessao_veiculo_tipo concessao_veiculo_tipo_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.concessao_veiculo_tipo
    ADD CONSTRAINT concessao_veiculo_tipo_pkey PRIMARY KEY (nome);


--
-- Name: declaracao declaracao_pk; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.declaracao
    ADD CONSTRAINT declaracao_pk PRIMARY KEY (id);


--
-- Name: eixo eixo_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.eixo
    ADD CONSTRAINT eixo_pkey PRIMARY KEY (nome);


--
-- Name: embarcacao_material_casco embarcacao_material_casco_nome_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao_material_casco
    ADD CONSTRAINT embarcacao_material_casco_nome_pkey PRIMARY KEY (nome);


--
-- Name: embarcacao_modelo embarcacao_modelo_nome_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao_modelo
    ADD CONSTRAINT embarcacao_modelo_nome_pkey PRIMARY KEY (nome);


--
-- Name: embarcacao_qualidade embarcacao_qualidade_nome_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao_qualidade
    ADD CONSTRAINT embarcacao_qualidade_nome_pkey PRIMARY KEY (nome);


--
-- Name: embarcacao embarcacao_registro_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_registro_pkey PRIMARY KEY (registro);


--
-- Name: embarcacao_tipo embarcacao_tipo_nome_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao_tipo
    ADD CONSTRAINT embarcacao_tipo_nome_pkey PRIMARY KEY (nome);


--
-- Name: empresa_hidroviario empresa_hidroviario_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.empresa_hidroviario
    ADD CONSTRAINT empresa_hidroviario_pkey PRIMARY KEY (cnpj);


--
-- Name: horario_hidroviario horario_hidroviario_id_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario_hidroviario
    ADD CONSTRAINT horario_hidroviario_id_pkey PRIMARY KEY (horario_id);


--
-- Name: horario horario_id_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario
    ADD CONSTRAINT horario_id_pkey PRIMARY KEY (horario_id);


--
-- Name: horario_semana horario_semana_horario_id_pk; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario_semana
    ADD CONSTRAINT horario_semana_horario_id_pk PRIMARY KEY (horario_id);


--
-- Name: horario_verao horario_verao_id_pk; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario_verao
    ADD CONSTRAINT horario_verao_id_pk PRIMARY KEY (horario_verao_id);


--
-- Name: itinerario_hidroviario itnerario_hidroviario_id_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_hidroviario
    ADD CONSTRAINT itnerario_hidroviario_id_pkey PRIMARY KEY (itinerario_hidroviario_id);


--
-- Name: itinerario_verao itnerario_id_pk; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_verao
    ADD CONSTRAINT itnerario_id_pk PRIMARY KEY (itinerario_verao_id);


--
-- Name: itinerario itnerario_id_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario
    ADD CONSTRAINT itnerario_id_pkey PRIMARY KEY (itinerario_id);


--
-- Name: linha_caracteristica linha_caracteristica_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_caracteristica
    ADD CONSTRAINT linha_caracteristica_pkey PRIMARY KEY (nome);


--
-- Name: linha_hidroviario linha_hidroviario_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_pkey PRIMARY KEY (codigo);


--
-- Name: linha_historico linha_historico_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_historico
    ADD CONSTRAINT linha_historico_pkey PRIMARY KEY (id);


--
-- Name: linha_modalidade linha_modalidade_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_modalidade
    ADD CONSTRAINT linha_modalidade_pkey PRIMARY KEY (nome);


--
-- Name: linha linha_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_pkey PRIMARY KEY (codigo);


--
-- Name: linha_servico linha_servico_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_servico
    ADD CONSTRAINT linha_servico_pkey PRIMARY KEY (nome);


--
-- Name: mostra_verao mostra_verao_pk; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.mostra_verao
    ADD CONSTRAINT mostra_verao_pk PRIMARY KEY (id);


--
-- Name: empresa_hidroviario_diretor nome__empresa_hidroviario_cnpj_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.empresa_hidroviario_diretor
    ADD CONSTRAINT nome__empresa_hidroviario_cnpj_pkey PRIMARY KEY (empresa_hidroviario_cnpj, nome);


--
-- Name: ordem_servico_hidroviario numero_os_hidroviario_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico_hidroviario
    ADD CONSTRAINT numero_os_hidroviario_pkey PRIMARY KEY (numero);


--
-- Name: ordem_servico numero_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico
    ADD CONSTRAINT numero_pkey PRIMARY KEY (numero);


--
-- Name: ordem_servico__linha ordem_servico__linha_id_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico__linha
    ADD CONSTRAINT ordem_servico__linha_id_pkey PRIMARY KEY (ordem_servico__linha_id);


--
-- Name: ordem_servico_assunto ordem_servico_assunto_descricao_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico_assunto
    ADD CONSTRAINT ordem_servico_assunto_descricao_pkey PRIMARY KEY (descricao);


--
-- Name: ordem_servico_hidroviario__linha_hidroviario ordem_servico_hidroviario__linha_hidroviario_id_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico_hidroviario__linha_hidroviario
    ADD CONSTRAINT ordem_servico_hidroviario__linha_hidroviario_id_pkey PRIMARY KEY (ordem_servico_hidroviario__linha_hidroviario_id);


--
-- Name: parecer_tecnico parecer_tecnico_processo_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.parecer_tecnico
    ADD CONSTRAINT parecer_tecnico_processo_pkey PRIMARY KEY (processo);


--
-- Name: secao_tarifaria secao_tarifaria_id_pkey; Type: CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.secao_tarifaria
    ADD CONSTRAINT secao_tarifaria_id_pkey PRIMARY KEY (secao_tarifaria_id);


--
-- Name: documento_empresa documento_empresa_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_empresa
    ADD CONSTRAINT documento_empresa_pkey PRIMARY KEY (id);


--
-- Name: documento_motorista documento_motorista_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_motorista
    ADD CONSTRAINT documento_motorista_pkey PRIMARY KEY (id);


--
-- Name: documento documento_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento
    ADD CONSTRAINT documento_pkey PRIMARY KEY (id);


--
-- Name: documento_tipo_permissao documento_tipo_permissao_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_tipo_permissao
    ADD CONSTRAINT documento_tipo_permissao_pkey PRIMARY KEY (tipo_nome, entidade_tipo);


--
-- Name: documento_tipo documento_tipo_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_tipo
    ADD CONSTRAINT documento_tipo_pkey PRIMARY KEY (nome);


--
-- Name: documento_usuario documento_usuario_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_usuario
    ADD CONSTRAINT documento_usuario_pkey PRIMARY KEY (id);


--
-- Name: documento_veiculo documento_veiculo_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_veiculo
    ADD CONSTRAINT documento_veiculo_pkey PRIMARY KEY (id);


--
-- Name: documento_viagem documento_viagem_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_viagem
    ADD CONSTRAINT documento_viagem_pkey PRIMARY KEY (id);


--
-- Name: fluxo_pendencia fluxo_pendencia_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_pkey PRIMARY KEY (id);


--
-- Name: motorista motorista_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.motorista
    ADD CONSTRAINT motorista_pkey PRIMARY KEY (id);


--
-- Name: passageiro passageiro_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.passageiro
    ADD CONSTRAINT passageiro_pkey PRIMARY KEY (id);


--
-- Name: passageiro passageiro_unique_viagem_cpf; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.passageiro
    ADD CONSTRAINT passageiro_unique_viagem_cpf UNIQUE (viagem_id, cpf);


--
-- Name: status_pendencia status_pendencia_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.status_pendencia
    ADD CONSTRAINT status_pendencia_pkey PRIMARY KEY (status);


--
-- Name: tipo_entidade_pendencia tipo_entidade_pendencia_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.tipo_entidade_pendencia
    ADD CONSTRAINT tipo_entidade_pendencia_pkey PRIMARY KEY (tipo);


--
-- Name: viagem viagem_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_pkey PRIMARY KEY (id);


--
-- Name: viagem_tipo viagem_tipo_pkey; Type: CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem_tipo
    ADD CONSTRAINT viagem_tipo_pkey PRIMARY KEY (nome);


--
-- Name: _rel_4ok _rel_4ok_placa_pk; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento._rel_4ok
    ADD CONSTRAINT _rel_4ok_placa_pk PRIMARY KEY (placa);


--
-- Name: _rel_total _rel_total_placa_pk; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento._rel_total
    ADD CONSTRAINT _rel_total_placa_pk PRIMARY KEY (placa);


--
-- Name: autorizacao_emitida autorizacao_emitida_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao_emitida
    ADD CONSTRAINT autorizacao_emitida_pkey PRIMARY KEY (autorizacao_emitida_id);


--
-- Name: codigo_barras codigo_barras_codigo_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.codigo_barras
    ADD CONSTRAINT codigo_barras_codigo_pkey PRIMARY KEY (codigo);


--
-- Name: autorizacao codigo_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao
    ADD CONSTRAINT codigo_pkey PRIMARY KEY (codigo);


--
-- Name: contratante contratante_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contratante
    ADD CONSTRAINT contratante_pkey PRIMARY KEY (codigo);


--
-- Name: contrato_itinerario contrato_itinerario_contrato_placa_saida_uni; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato_itinerario
    ADD CONSTRAINT contrato_itinerario_contrato_placa_saida_uni UNIQUE (contrato_codigo, veiculo_placa, municipio_nome_saida);


--
-- Name: contrato_itinerario contrato_itinerario_id_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato_itinerario
    ADD CONSTRAINT contrato_itinerario_id_pkey PRIMARY KEY (itinerario_id);


--
-- Name: contrato contrato_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato
    ADD CONSTRAINT contrato_pkey PRIMARY KEY (codigo);


--
-- Name: documento_contratado documento_contratado_nome_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.documento_contratado
    ADD CONSTRAINT documento_contratado_nome_pkey PRIMARY KEY (nome);


--
-- Name: documento_contrato documento_contrato_nome_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.documento_contrato
    ADD CONSTRAINT documento_contrato_nome_pkey PRIMARY KEY (nome);


--
-- Name: documento_veiculo documento_veiculo_nome_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.documento_veiculo
    ADD CONSTRAINT documento_veiculo_nome_pkey PRIMARY KEY (nome);


--
-- Name: emplacamento emplacamento_chassi_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.emplacamento
    ADD CONSTRAINT emplacamento_chassi_pkey PRIMARY KEY (chassi);


--
-- Name: entidade entidade_nome_pk; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.entidade
    ADD CONSTRAINT entidade_nome_pk PRIMARY KEY (nome);


--
-- Name: fretamento_processo fretamento_processo_codigo_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.fretamento_processo
    ADD CONSTRAINT fretamento_processo_codigo_pkey PRIMARY KEY (codigo);


--
-- Name: fretamento_veiculo_tipo fretamento_veiculo_tipo_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.fretamento_veiculo_tipo
    ADD CONSTRAINT fretamento_veiculo_tipo_pkey PRIMARY KEY (nome);


--
-- Name: guia guia_id_pk; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.guia
    ADD CONSTRAINT guia_id_pk PRIMARY KEY (id);


--
-- Name: historico historico_pk; Type: CONSTRAINT; Schema: fretamento; Owner: postgres
--

ALTER TABLE ONLY fretamento.historico
    ADD CONSTRAINT historico_pk PRIMARY KEY (id);


--
-- Name: hlp hlp_id_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.hlp
    ADD CONSTRAINT hlp_id_pkey PRIMARY KEY (id);


--
-- Name: hlpa hlpa_id_fkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.hlpa
    ADD CONSTRAINT hlpa_id_fkey PRIMARY KEY (hlpa_id);


--
-- Name: identificacao identificacao_tipo_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.identificacao
    ADD CONSTRAINT identificacao_tipo_pkey PRIMARY KEY (nome);


--
-- Name: laudo_vistoria laudo_vistoria_id_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.laudo_vistoria
    ADD CONSTRAINT laudo_vistoria_id_pkey PRIMARY KEY (laudo_vistoria_id);


--
-- Name: lista_passageiros lista_passageiros_contrato_pk; Type: CONSTRAINT; Schema: fretamento; Owner: postgres
--

ALTER TABLE ONLY fretamento.lista_passageiros
    ADD CONSTRAINT lista_passageiros_contrato_pk PRIMARY KEY (contrato_codigo);


--
-- Name: vencimento_seguradora placa_data_unique; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.vencimento_seguradora
    ADD CONSTRAINT placa_data_unique UNIQUE (placa, vencimento);


--
-- Name: qr qr_veiculo_placa_pk; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.qr
    ADD CONSTRAINT qr_veiculo_placa_pk PRIMARY KEY (veiculo_placa);


--
-- Name: seguradora seguradora_pk; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.seguradora
    ADD CONSTRAINT seguradora_pk PRIMARY KEY (nome);


--
-- Name: servico servico_nome_pkey; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.servico
    ADD CONSTRAINT servico_nome_pkey PRIMARY KEY (nome);


--
-- Name: vencimento_seguradora vs_pk; Type: CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.vencimento_seguradora
    ADD CONSTRAINT vs_pk PRIMARY KEY (id);


--
-- Name: acordo__empresa acordo__empresa_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.acordo__empresa
    ADD CONSTRAINT acordo__empresa_pkey PRIMARY KEY (acordo_codigo);


--
-- Name: acordo acordo_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.acordo
    ADD CONSTRAINT acordo_pkey PRIMARY KEY (codigo);


--
-- Name: veiculo_carroceria carroceria_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_carroceria
    ADD CONSTRAINT carroceria_pkey PRIMARY KEY (nome);


--
-- Name: veiculo_chassi chassi_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_chassi
    ADD CONSTRAINT chassi_pkey PRIMARY KEY (nome);


--
-- Name: classificacao_inmetro classificacao_inmetro_nome_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.classificacao_inmetro
    ADD CONSTRAINT classificacao_inmetro_nome_pkey PRIMARY KEY (nome);


--
-- Name: empresa_codigo codigo_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa_codigo
    ADD CONSTRAINT codigo_pkey PRIMARY KEY (codigo);


--
-- Name: veiculo_combustivel combustivel_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_combustivel
    ADD CONSTRAINT combustivel_pkey PRIMARY KEY (nome);


--
-- Name: cor cor_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.cor
    ADD CONSTRAINT cor_pkey PRIMARY KEY (nome);


--
-- Name: empresa empresa_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa
    ADD CONSTRAINT empresa_pkey PRIMARY KEY (cnpj);


--
-- Name: engenheiro engenheiro_nome_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.engenheiro
    ADD CONSTRAINT engenheiro_nome_pkey PRIMARY KEY (nome);


--
-- Name: excluir_seguro excluir_seguro_pk; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.excluir_seguro
    ADD CONSTRAINT excluir_seguro_pk PRIMARY KEY (id);


--
-- Name: feriado feriado_pk; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.feriado
    ADD CONSTRAINT feriado_pk PRIMARY KEY (id);


--
-- Name: metroplan id_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.metroplan
    ADD CONSTRAINT id_pkey PRIMARY KEY (id);


--
-- Name: itl_vistoria itl_vistoria_id_pk; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.itl_vistoria
    ADD CONSTRAINT itl_vistoria_id_pk PRIMARY KEY (id);


--
-- Name: itl_vistoria itl_vistoria_un; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.itl_vistoria
    ADD CONSTRAINT itl_vistoria_un UNIQUE (veiculo_placa, data, validade);


--
-- Name: logradouro logradouro_id_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.logradouro
    ADD CONSTRAINT logradouro_id_pkey PRIMARY KEY (logradouro_id);


--
-- Name: municipio municipio_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.municipio
    ADD CONSTRAINT municipio_pkey PRIMARY KEY (nome);


--
-- Name: empresa_diretor nome__empresa_cnpj_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa_diretor
    ADD CONSTRAINT nome__empresa_cnpj_pkey PRIMARY KEY (empresa_cnpj, nome);


--
-- Name: validador_be numero_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.validador_be
    ADD CONSTRAINT numero_pkey PRIMARY KEY (numero);


--
-- Name: regiao regiao_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.regiao
    ADD CONSTRAINT regiao_pkey PRIMARY KEY (codigo);


--
-- Name: veiculo_alteracao veiculo_alteracao_id_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_alteracao
    ADD CONSTRAINT veiculo_alteracao_id_pkey PRIMARY KEY (veiculo_alteracao_id);


--
-- Name: veiculo_declaracao veiculo_declaracao_id_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_declaracao
    ADD CONSTRAINT veiculo_declaracao_id_pkey PRIMARY KEY (veiculo_declaracao_id);


--
-- Name: veiculo_modelo veiculo_modelo_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_modelo
    ADD CONSTRAINT veiculo_modelo_pkey PRIMARY KEY (nome);


--
-- Name: veiculo_motor veiculo_motor_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_motor
    ADD CONSTRAINT veiculo_motor_pkey PRIMARY KEY (nome);


--
-- Name: veiculo veiculo_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_pkey PRIMARY KEY (placa);


--
-- Name: veiculo_qualidade veiculo_qualidade_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_qualidade
    ADD CONSTRAINT veiculo_qualidade_pkey PRIMARY KEY (nome);


--
-- Name: veiculo_rodados veiculo_rodados_nome_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_rodados
    ADD CONSTRAINT veiculo_rodados_nome_pkey PRIMARY KEY (nome);


--
-- Name: veiculo_vistoria veiculo_vistoria_id_pkey; Type: CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo_vistoria
    ADD CONSTRAINT veiculo_vistoria_id_pkey PRIMARY KEY (veiculo_vistoria_id);


--
-- Name: rota rota_id_pk; Type: CONSTRAINT; Schema: gm; Owner: metroplan
--

ALTER TABLE ONLY gm.rota
    ADD CONSTRAINT rota_id_pk PRIMARY KEY (id);


--
-- Name: rota rota_linha_ida_uni; Type: CONSTRAINT; Schema: gm; Owner: metroplan
--

ALTER TABLE ONLY gm.rota
    ADD CONSTRAINT rota_linha_ida_uni UNIQUE (linha_codigo, ida);


--
-- Name: admin motorista_admin_cpf_pk; Type: CONSTRAINT; Schema: motorista; Owner: metroplan
--

ALTER TABLE ONLY motorista.admin
    ADD CONSTRAINT motorista_admin_cpf_pk PRIMARY KEY (cpf);


--
-- Name: motorista motorista_cnh_un; Type: CONSTRAINT; Schema: motorista; Owner: metroplan
--

ALTER TABLE ONLY motorista.motorista
    ADD CONSTRAINT motorista_cnh_un UNIQUE (cnh);


--
-- Name: motorista motorista_cpf_pk; Type: CONSTRAINT; Schema: motorista; Owner: metroplan
--

ALTER TABLE ONLY motorista.motorista
    ADD CONSTRAINT motorista_cpf_pk PRIMARY KEY (cpf);


--
-- Name: empresa motorista_empresa_cnpj_pk; Type: CONSTRAINT; Schema: motorista; Owner: metroplan
--

ALTER TABLE ONLY motorista.empresa
    ADD CONSTRAINT motorista_empresa_cnpj_pk PRIMARY KEY (cnpj);


--
-- Name: usuario motorista_usuario_cpf_pk; Type: CONSTRAINT; Schema: motorista; Owner: metroplan
--

ALTER TABLE ONLY motorista.usuario
    ADD CONSTRAINT motorista_usuario_cpf_pk PRIMARY KEY (cpf);


--
-- Name: auto auto_codigo_pkey; Type: CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.auto
    ADD CONSTRAINT auto_codigo_pkey PRIMARY KEY (codigo);


--
-- Name: devedor devedor_id_pkey; Type: CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.devedor
    ADD CONSTRAINT devedor_id_pkey PRIMARY KEY (id);


--
-- Name: fiscal fiscal_pkey; Type: CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.fiscal
    ADD CONSTRAINT fiscal_pkey PRIMARY KEY (matricula);


--
-- Name: carro multas_carro_pk; Type: CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.carro
    ADD CONSTRAINT multas_carro_pk PRIMARY KEY (placa);


--
-- Name: infrator multas_infrator_pk; Type: CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.infrator
    ADD CONSTRAINT multas_infrator_pk PRIMARY KEY (cnpj_cpf);


--
-- Name: municipio multas_municipio_nome_pk; Type: CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.municipio
    ADD CONSTRAINT multas_municipio_nome_pk PRIMARY KEY (nome);


--
-- Name: penalidade tmp_pena_pk; Type: CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.penalidade
    ADD CONSTRAINT tmp_pena_pk PRIMARY KEY (subgrupo);


--
-- Name: ocorrencia_assunto assunto_nome_pkey; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_assunto
    ADD CONSTRAINT assunto_nome_pkey PRIMARY KEY (nome);


--
-- Name: ocorrencia_assunto_tipo ocorrencia_assunto_tipo_pkey; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_assunto_tipo
    ADD CONSTRAINT ocorrencia_assunto_tipo_pkey PRIMARY KEY (nome);


--
-- Name: ocorrencia ocorrencia_id_pkey; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT ocorrencia_id_pkey PRIMARY KEY (ocorrencia_id);


--
-- Name: ocorrencia_tipo ocorrencia_tipo_nome_pkey; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_tipo
    ADD CONSTRAINT ocorrencia_tipo_nome_pkey PRIMARY KEY (nome);


--
-- Name: andamento saac_andamento_id_pk; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.andamento
    ADD CONSTRAINT saac_andamento_id_pk PRIMARY KEY (id);


--
-- Name: ocorrencia_canal saac_canal_nome_pk; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_canal
    ADD CONSTRAINT saac_canal_nome_pk PRIMARY KEY (nome);


--
-- Name: departamento saac_departamento_nome_pk; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.departamento
    ADD CONSTRAINT saac_departamento_nome_pk PRIMARY KEY (nome);


--
-- Name: ocorrencia_prioridade saac_prioridade_nome_pk; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_prioridade
    ADD CONSTRAINT saac_prioridade_nome_pk PRIMARY KEY (nome);


--
-- Name: ocorrencia_situacao saac_tipo_nome_pk; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_situacao
    ADD CONSTRAINT saac_tipo_nome_pk PRIMARY KEY (nome);


--
-- Name: ocorrencia_servico servico_nome_pkey; Type: CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_servico
    ADD CONSTRAINT servico_nome_pkey PRIMARY KEY (nome);


--
-- Name: auto temp_auto_codigo_uniq; Type: CONSTRAINT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.auto
    ADD CONSTRAINT temp_auto_codigo_uniq UNIQUE (codigo);


--
-- Name: auto temp_auto_pk; Type: CONSTRAINT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.auto
    ADD CONSTRAINT temp_auto_pk PRIMARY KEY (id);


--
-- Name: fiscal temp_fiscal_pk; Type: CONSTRAINT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.fiscal
    ADD CONSTRAINT temp_fiscal_pk PRIMARY KEY (codigo);


--
-- Name: multa temp_multa_pk; Type: CONSTRAINT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.multa
    ADD CONSTRAINT temp_multa_pk PRIMARY KEY (id);


--
-- Name: municipio temp_muni_pk; Type: CONSTRAINT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.municipio
    ADD CONSTRAINT temp_muni_pk PRIMARY KEY (codigo);


--
-- Name: penalidade tmp_pena_pk; Type: CONSTRAINT; Schema: temp; Owner: metroplan
--

ALTER TABLE ONLY temp.penalidade
    ADD CONSTRAINT tmp_pena_pk PRIMARY KEY (subgrupo);


--
-- Name: papel papel_pkey; Type: CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.papel
    ADD CONSTRAINT papel_pkey PRIMARY KEY (nome);


--
-- Name: token_validacao_email token_validacao_email_pkey; Type: CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.token_validacao_email
    ADD CONSTRAINT token_validacao_email_pkey PRIMARY KEY (id);


--
-- Name: token_validacao_email token_validacao_email_token_key; Type: CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.token_validacao_email
    ADD CONSTRAINT token_validacao_email_token_key UNIQUE (token);


--
-- Name: usuario usuario_cpf_key; Type: CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_cpf_key UNIQUE (cpf);


--
-- Name: usuario usuario_email_key; Type: CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_email_key UNIQUE (email);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- Name: eixo_nome_key; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE UNIQUE INDEX eixo_nome_key ON concessao.eixo USING btree (nome);


--
-- Name: horario_hidroviario_linha_hidroviario_codigo_idx; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX horario_hidroviario_linha_hidroviario_codigo_idx ON concessao.horario_hidroviario USING btree (linha_hidroviario_codigo);


--
-- Name: horario_linha_codigo_idx; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX horario_linha_codigo_idx ON concessao.horario USING btree (linha_codigo);


--
-- Name: horario_verao_linha_codigo_idx; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX horario_verao_linha_codigo_idx ON concessao.horario_verao USING btree (linha_codigo);


--
-- Name: idx_linha_historico_codigo; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX idx_linha_historico_codigo ON concessao.linha_historico USING btree (linha_codigo);


--
-- Name: idx_linha_historico_datas; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX idx_linha_historico_datas ON concessao.linha_historico USING btree (data_historico_inicio, data_historico_fim);


--
-- Name: idx_linha_historico_empresa; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX idx_linha_historico_empresa ON concessao.linha_historico USING btree (empresa_codigo);


--
-- Name: idx_linha_historico_exclusao; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX idx_linha_historico_exclusao ON concessao.linha_historico USING btree (data_exclusao);


--
-- Name: idx_linha_historico_nome; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX idx_linha_historico_nome ON concessao.linha_historico USING btree (linha_nome);


--
-- Name: idx_linha_historico_ordem_servico; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX idx_linha_historico_ordem_servico ON concessao.linha_historico USING btree (ordem_servico_numero);


--
-- Name: idx_linha_historico_vigencia; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX idx_linha_historico_vigencia ON concessao.linha_historico USING btree (data_vigencia, data_validade);


--
-- Name: linha_codigo_idx; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX linha_codigo_idx ON concessao.ordem_servico__linha USING btree (linha_codigo);


--
-- Name: linha_codigo_key; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE UNIQUE INDEX linha_codigo_key ON concessao.linha USING btree (codigo);


--
-- Name: linha_hidroviario_codigo_idx; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX linha_hidroviario_codigo_idx ON concessao.ordem_servico_hidroviario__linha_hidroviario USING btree (linha_hidroviario_codigo);


--
-- Name: linha_hidroviario_codigo_key; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE UNIQUE INDEX linha_hidroviario_codigo_key ON concessao.linha USING btree (codigo);


--
-- Name: ordem_servico_hidroviario_numero_idx; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX ordem_servico_hidroviario_numero_idx ON concessao.ordem_servico_hidroviario__linha_hidroviario USING btree (ordem_servico_hidroviario_numero);


--
-- Name: ordem_servico_numero_idx; Type: INDEX; Schema: concessao; Owner: metroplan
--

CREATE INDEX ordem_servico_numero_idx ON concessao.ordem_servico__linha USING btree (ordem_servico_numero);


--
-- Name: documento_validade_idx; Type: INDEX; Schema: eventual; Owner: postgres
--

CREATE INDEX documento_validade_idx ON eventual.documento USING btree (validade);


--
-- Name: fluxo_pendencia_entidade_idx; Type: INDEX; Schema: eventual; Owner: postgres
--

CREATE INDEX fluxo_pendencia_entidade_idx ON eventual.fluxo_pendencia USING btree (entidade_tipo, entidade_id);


--
-- Name: fluxo_pendencia_latest_idx; Type: INDEX; Schema: eventual; Owner: postgres
--

CREATE INDEX fluxo_pendencia_latest_idx ON eventual.fluxo_pendencia USING btree (entidade_tipo, entidade_id, criado_em DESC);


--
-- Name: autorizacao_contrato_codigo_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX autorizacao_contrato_codigo_idx ON fretamento.autorizacao USING btree (contrato_codigo);


--
-- Name: autorizacao_contrato_placa_data_inicio_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX autorizacao_contrato_placa_data_inicio_idx ON fretamento.autorizacao USING btree (contrato_codigo, veiculo_placa, data_inicio);


--
-- Name: autorizacao_contrato_placa_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX autorizacao_contrato_placa_idx ON fretamento.autorizacao USING btree (veiculo_placa, contrato_codigo);


--
-- Name: autorizacao_placa_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX autorizacao_placa_idx ON fretamento.autorizacao USING btree (veiculo_placa);


--
-- Name: ci_contrato_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX ci_contrato_idx ON fretamento.contrato_itinerario USING btree (contrato_codigo);


--
-- Name: ci_placa; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX ci_placa ON fretamento.contrato_itinerario USING btree (veiculo_placa);


--
-- Name: ci_placa_cont_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX ci_placa_cont_idx ON fretamento.contrato_itinerario USING btree (veiculo_placa, contrato_codigo);


--
-- Name: fret_contrato_data_fim_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX fret_contrato_data_fim_idx ON fretamento.contrato USING btree (data_fim);


--
-- Name: laudo_vistoria_validade_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX laudo_vistoria_validade_idx ON fretamento.laudo_vistoria USING btree (data_validade);


--
-- Name: laudo_vistoria_veiculo_placa_idx; Type: INDEX; Schema: fretamento; Owner: metroplan
--

CREATE INDEX laudo_vistoria_veiculo_placa_idx ON fretamento.laudo_vistoria USING btree (veiculo_placa);


--
-- Name: feriado_data_idx; Type: INDEX; Schema: geral; Owner: metroplan
--

CREATE INDEX feriado_data_idx ON geral.feriado USING btree (data);


--
-- Name: logradouro_municipio_uidx; Type: INDEX; Schema: geral; Owner: metroplan
--

CREATE UNIQUE INDEX logradouro_municipio_uidx ON geral.logradouro USING btree (nome, municipio_nome);


--
-- Name: municipio_nome_key; Type: INDEX; Schema: geral; Owner: metroplan
--

CREATE UNIQUE INDEX municipio_nome_key ON geral.municipio USING btree (nome);


--
-- Name: veiculo_inclusao_fret_idx; Type: INDEX; Schema: geral; Owner: metroplan
--

CREATE INDEX veiculo_inclusao_fret_idx ON geral.veiculo USING btree (data_inclusao_fretamento);


--
-- Name: veiculo_seguro_idx; Type: INDEX; Schema: geral; Owner: metroplan
--

CREATE INDEX veiculo_seguro_idx ON geral.veiculo USING btree (data_vencimento_seguro);


--
-- Name: veiculo_vistoria_placa_idx; Type: INDEX; Schema: geral; Owner: metroplan
--

CREATE INDEX veiculo_vistoria_placa_idx ON geral.veiculo_vistoria USING btree (veiculo_placa);


--
-- Name: idx_token_validacao_email_token; Type: INDEX; Schema: web; Owner: postgres
--

CREATE INDEX idx_token_validacao_email_token ON web.token_validacao_email USING btree (token);


--
-- Name: idx_token_validacao_email_usuario; Type: INDEX; Schema: web; Owner: postgres
--

CREATE INDEX idx_token_validacao_email_usuario ON web.token_validacao_email USING btree (usuario_id);


--
-- Name: idx_usuario_email; Type: INDEX; Schema: web; Owner: postgres
--

CREATE INDEX idx_usuario_email ON web.usuario USING btree (email);


--
-- Name: idx_usuario_empresa_cnpj; Type: INDEX; Schema: web; Owner: postgres
--

CREATE INDEX idx_usuario_empresa_cnpj ON web.usuario USING btree (empresa_cnpj);


--
-- Name: consulta_veiculo_site _RETURN; Type: RULE; Schema: fretamento; Owner: metroplan
--

CREATE OR REPLACE VIEW fretamento.consulta_veiculo_site AS
 SELECT DISTINCT veiculo.placa,
    veiculo.crlv,
    veiculo.data_vencimento_seguro AS vencimento_seguro,
    ( SELECT laudo_vistoria.data_validade
           FROM fretamento.laudo_vistoria
          WHERE (laudo_vistoria.veiculo_placa = veiculo.placa)
          ORDER BY laudo_vistoria.data_validade DESC
         LIMIT 1) AS vistoria_data,
    ( SELECT contrato_itinerario.contrato_codigo
           FROM fretamento.contrato contrato_1,
            fretamento.contrato_itinerario
          WHERE ((contrato_itinerario.veiculo_placa = veiculo.placa) AND (contrato_itinerario.contrato_codigo = contrato_1.codigo))
          ORDER BY contrato_1.data_fim DESC
         LIMIT 1) AS contrato_codigo,
    contrato.data_fim AS contrato_vencimento,
    (( SELECT (autorizacao_1.data_inicio + '1 year'::interval)
           FROM fretamento.autorizacao autorizacao_1
          WHERE ((autorizacao_1.contrato_codigo = autorizacao_1.contrato_codigo) AND (autorizacao_1.veiculo_placa = veiculo.placa))
          ORDER BY autorizacao_1.data_inicio DESC
         LIMIT 1))::date AS validade_taxa,
    ( SELECT empresa.nome AS empresa
           FROM geral.empresa
          WHERE (empresa.cnpj = veiculo.empresa_cnpj)
         LIMIT 1) AS empresa
   FROM geral.veiculo,
    fretamento.contrato,
    fretamento.autorizacao
  WHERE ((autorizacao.contrato_codigo = contrato.codigo) AND (autorizacao.veiculo_placa = veiculo.placa) AND ((veiculo.data_exclusao_fretamento IS NULL) OR (veiculo.data_exclusao_fretamento > now())))
  GROUP BY veiculo.placa, contrato.codigo, ( SELECT laudo_vistoria.data_validade
           FROM fretamento.laudo_vistoria
          WHERE (laudo_vistoria.veiculo_placa = veiculo.placa)
          ORDER BY laudo_vistoria.data_validade DESC
         LIMIT 1), ( SELECT empresa.nome AS empresa
           FROM geral.empresa
          WHERE (empresa.cnpj = veiculo.empresa_cnpj)
         LIMIT 1)
  ORDER BY veiculo.placa, contrato.data_fim DESC, ( SELECT laudo_vistoria.data_validade
           FROM fretamento.laudo_vistoria
          WHERE (laudo_vistoria.veiculo_placa = veiculo.placa)
          ORDER BY laudo_vistoria.data_validade DESC
         LIMIT 1) DESC;


--
-- Name: horario trg_historico_linha_after_horario; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER trg_historico_linha_after_horario AFTER INSERT OR DELETE OR UPDATE ON concessao.horario FOR EACH ROW EXECUTE FUNCTION concessao.trigger_historico_linha_on_horario();


--
-- Name: linha trg_historico_linha_after_linha; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER trg_historico_linha_after_linha AFTER INSERT OR UPDATE ON concessao.linha FOR EACH ROW EXECUTE FUNCTION concessao.trigger_historico_linha_on_linha();


--
-- Name: ordem_servico trg_historico_linha_after_ordem_servico; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER trg_historico_linha_after_ordem_servico AFTER INSERT OR DELETE OR UPDATE ON concessao.ordem_servico FOR EACH ROW EXECUTE FUNCTION concessao.trigger_historico_linha_on_ordem_servico();


--
-- Name: ordem_servico__linha trg_historico_linha_after_ordem_servico__linha; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER trg_historico_linha_after_ordem_servico__linha AFTER INSERT OR DELETE OR UPDATE ON concessao.ordem_servico__linha FOR EACH ROW EXECUTE FUNCTION concessao.trigger_historico_linha_on_ordem_servico__linha();


--
-- Name: empresa_codigo_hidroviario upper_codigo; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_codigo BEFORE INSERT OR UPDATE ON concessao.empresa_codigo_hidroviario FOR EACH ROW EXECUTE FUNCTION geral.upper_codigo();


--
-- Name: ordem_servico_assunto upper_descricao; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_descricao BEFORE INSERT OR UPDATE ON concessao.ordem_servico_assunto FOR EACH ROW EXECUTE FUNCTION geral.upper_descricao();


--
-- Name: empresa_hidroviario upper_empresa; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_empresa BEFORE INSERT OR UPDATE ON concessao.empresa_hidroviario FOR EACH ROW EXECUTE FUNCTION geral.upper_empresa();


--
-- Name: itinerario upper_itinerario; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_itinerario BEFORE INSERT OR UPDATE ON concessao.itinerario FOR EACH ROW EXECUTE FUNCTION concessao.upper_itinerario();


--
-- Name: itinerario_hidroviario upper_itinerario; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_itinerario BEFORE INSERT OR UPDATE ON concessao.itinerario_hidroviario FOR EACH ROW EXECUTE FUNCTION concessao.upper_itinerario();


--
-- Name: itinerario_verao upper_itinerario; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_itinerario BEFORE INSERT OR UPDATE ON concessao.itinerario_verao FOR EACH ROW EXECUTE FUNCTION concessao.upper_itinerario();


--
-- Name: linha upper_linha; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_linha BEFORE INSERT OR UPDATE ON concessao.linha FOR EACH ROW EXECUTE FUNCTION concessao.upper_linha();


--
-- Name: linha_hidroviario upper_linha_hidroviario; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_linha_hidroviario BEFORE INSERT OR UPDATE ON concessao.linha_hidroviario FOR EACH ROW EXECUTE FUNCTION concessao.upper_linha_hidroviario();


--
-- Name: concessao_veiculo_tipo upper_nome; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON concessao.concessao_veiculo_tipo FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: eixo upper_nome; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON concessao.eixo FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: empresa_hidroviario_diretor upper_nome; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON concessao.empresa_hidroviario_diretor FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: linha_caracteristica upper_nome; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON concessao.linha_caracteristica FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: linha_modalidade upper_nome; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON concessao.linha_modalidade FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: linha_servico upper_nome; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON concessao.linha_servico FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: horario upper_observacoes; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_observacoes BEFORE INSERT OR UPDATE ON concessao.horario FOR EACH ROW EXECUTE FUNCTION geral.upper_observacoes();


--
-- Name: horario_hidroviario upper_observacoes; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_observacoes BEFORE INSERT OR UPDATE ON concessao.horario_hidroviario FOR EACH ROW EXECUTE FUNCTION geral.upper_observacoes();


--
-- Name: horario_verao upper_observacoes; Type: TRIGGER; Schema: concessao; Owner: metroplan
--

CREATE TRIGGER upper_observacoes BEFORE INSERT OR UPDATE ON concessao.horario_verao FOR EACH ROW EXECUTE FUNCTION geral.upper_observacoes();


--
-- Name: fluxo_pendencia trg_analista_obrigatorio; Type: TRIGGER; Schema: eventual; Owner: postgres
--

CREATE TRIGGER trg_analista_obrigatorio BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_analista_obrigatorio();


--
-- Name: fluxo_pendencia trg_evitar_status_repetido; Type: TRIGGER; Schema: eventual; Owner: postgres
--

CREATE TRIGGER trg_evitar_status_repetido BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_evitar_status_repetido();


--
-- Name: fluxo_pendencia trg_motivo_obrigatorio; Type: TRIGGER; Schema: eventual; Owner: postgres
--

CREATE TRIGGER trg_motivo_obrigatorio BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_motivo_obrigatorio();


--
-- Name: fluxo_pendencia trg_valida_entidade; Type: TRIGGER; Schema: eventual; Owner: postgres
--

CREATE TRIGGER trg_valida_entidade BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_valida_entidade();


--
-- Name: contratante upper_contratante; Type: TRIGGER; Schema: fretamento; Owner: metroplan
--

CREATE TRIGGER upper_contratante BEFORE INSERT OR UPDATE ON fretamento.contratante FOR EACH ROW EXECUTE FUNCTION fretamento.upper_contratante();


--
-- Name: entidade upper_contratante; Type: TRIGGER; Schema: fretamento; Owner: metroplan
--

CREATE TRIGGER upper_contratante BEFORE INSERT OR UPDATE ON fretamento.entidade FOR EACH ROW EXECUTE FUNCTION fretamento.upper_entidade();


--
-- Name: contrato upper_contrato; Type: TRIGGER; Schema: fretamento; Owner: metroplan
--

CREATE TRIGGER upper_contrato BEFORE INSERT OR UPDATE ON fretamento.contrato FOR EACH ROW EXECUTE FUNCTION fretamento.upper_contrato();


--
-- Name: fretamento_veiculo_tipo upper_nome; Type: TRIGGER; Schema: fretamento; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON fretamento.fretamento_veiculo_tipo FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: identificacao upper_nome; Type: TRIGGER; Schema: fretamento; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON fretamento.identificacao FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: itl_vistoria manda_vistoria; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER manda_vistoria BEFORE INSERT OR UPDATE ON geral.itl_vistoria FOR EACH ROW EXECUTE FUNCTION geral.manda_vistoria_tabela();


--
-- Name: empresa trg_registra_historico_empresa; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER trg_registra_historico_empresa AFTER UPDATE ON geral.empresa FOR EACH ROW EXECUTE FUNCTION concessao.trigger_registra_historico_por_empresa();


--
-- Name: empresa_codigo trg_registra_historico_on_empresa_codigo; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER trg_registra_historico_on_empresa_codigo AFTER INSERT OR DELETE OR UPDATE ON geral.empresa_codigo FOR EACH ROW EXECUTE FUNCTION concessao.trigger_historico_linha_on_empresa_codigo();


--
-- Name: acordo upper_codigo; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_codigo BEFORE INSERT OR UPDATE ON geral.acordo FOR EACH ROW EXECUTE FUNCTION geral.upper_codigo();


--
-- Name: empresa_codigo upper_codigo; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_codigo BEFORE INSERT OR UPDATE ON geral.empresa_codigo FOR EACH ROW EXECUTE FUNCTION geral.upper_codigo();


--
-- Name: regiao upper_codigo; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_codigo BEFORE INSERT OR UPDATE ON geral.regiao FOR EACH ROW EXECUTE FUNCTION geral.upper_codigo();


--
-- Name: metroplan upper_diretor; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_diretor BEFORE INSERT OR UPDATE ON geral.metroplan FOR EACH ROW EXECUTE FUNCTION geral.upper_diretor();


--
-- Name: empresa upper_empresa; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_empresa BEFORE INSERT OR UPDATE ON geral.empresa FOR EACH ROW EXECUTE FUNCTION geral.upper_empresa();


--
-- Name: acordo upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.acordo FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: cor upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.cor FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: empresa_diretor upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.empresa_diretor FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: municipio upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.municipio FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: regiao upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.regiao FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo_carroceria upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.veiculo_carroceria FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo_chassi upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.veiculo_chassi FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo_combustivel upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.veiculo_combustivel FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo_modelo upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.veiculo_modelo FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo_motor upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.veiculo_motor FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo_qualidade upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.veiculo_qualidade FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo_rodados upper_nome; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON geral.veiculo_rodados FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: veiculo upper_veiculo; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_veiculo BEFORE INSERT OR UPDATE ON geral.veiculo FOR EACH ROW EXECUTE FUNCTION geral.upper_veiculo();


--
-- Name: veiculo_vistoria upper_vistoria; Type: TRIGGER; Schema: geral; Owner: metroplan
--

CREATE TRIGGER upper_vistoria BEFORE INSERT OR UPDATE ON geral.veiculo_vistoria FOR EACH ROW EXECUTE FUNCTION geral.upper_vistoria();


--
-- Name: auto upper_auto; Type: TRIGGER; Schema: multas; Owner: metroplan
--

CREATE TRIGGER upper_auto BEFORE INSERT OR UPDATE ON multas.auto FOR EACH ROW EXECUTE FUNCTION multas.upper_auto();


--
-- Name: fiscal upper_fiscal; Type: TRIGGER; Schema: multas; Owner: metroplan
--

CREATE TRIGGER upper_fiscal BEFORE INSERT OR UPDATE ON multas.fiscal FOR EACH ROW EXECUTE FUNCTION multas.upper_fiscal();


--
-- Name: ocorrencia tg_seta_data_atendimento; Type: TRIGGER; Schema: saac; Owner: metroplan
--

CREATE TRIGGER tg_seta_data_atendimento BEFORE INSERT ON saac.ocorrencia FOR EACH ROW EXECUTE FUNCTION saac.tg_seta_data_atendimento();


--
-- Name: ocorrencia_assunto upper_nome; Type: TRIGGER; Schema: saac; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON saac.ocorrencia_assunto FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: ocorrencia_servico upper_nome; Type: TRIGGER; Schema: saac; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON saac.ocorrencia_servico FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: ocorrencia_tipo upper_nome; Type: TRIGGER; Schema: saac; Owner: metroplan
--

CREATE TRIGGER upper_nome BEFORE INSERT OR UPDATE ON saac.ocorrencia_tipo FOR EACH ROW EXECUTE FUNCTION geral.upper_nome();


--
-- Name: ocorrencia upper_ocorrencia; Type: TRIGGER; Schema: saac; Owner: metroplan
--

CREATE TRIGGER upper_ocorrencia BEFORE INSERT OR UPDATE ON saac.ocorrencia FOR EACH ROW EXECUTE FUNCTION saac.upper_ocorrencia();


--
-- Name: usuario trg_usuario_normalizar_email; Type: TRIGGER; Schema: web; Owner: postgres
--

CREATE TRIGGER trg_usuario_normalizar_email BEFORE INSERT OR UPDATE OF email ON web.usuario FOR EACH ROW EXECUTE FUNCTION web.normalizar_email_usuario();


--
-- Name: log admin_usuario_nome_fk; Type: FK CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.log
    ADD CONSTRAINT admin_usuario_nome_fk FOREIGN KEY (usuario_nome) REFERENCES admin.usuario(nome);


--
-- Name: usuario_permissao usuario_permissao_permissao_nome_fk; Type: FK CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.usuario_permissao
    ADD CONSTRAINT usuario_permissao_permissao_nome_fk FOREIGN KEY (usuario_nome) REFERENCES admin.usuario(nome);


--
-- Name: usuario_permissao usuario_permissao_usuario_nome_fk; Type: FK CONSTRAINT; Schema: admin; Owner: metroplan
--

ALTER TABLE ONLY admin.usuario_permissao
    ADD CONSTRAINT usuario_permissao_usuario_nome_fk FOREIGN KEY (permissao_nome) REFERENCES admin.permissao(nome);


--
-- Name: log_acesso app_log_acesso_placa_fk; Type: FK CONSTRAINT; Schema: app; Owner: metroplan
--

ALTER TABLE ONLY app.log_acesso
    ADD CONSTRAINT app_log_acesso_placa_fk FOREIGN KEY (placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: log_acesso usuario; Type: FK CONSTRAINT; Schema: app; Owner: metroplan
--

ALTER TABLE ONLY app.log_acesso
    ADD CONSTRAINT usuario FOREIGN KEY (usuario) REFERENCES admin.usuario(nome);


--
-- Name: empresa_codigo_hidroviario codigo_empresa_hidroviario_regiao_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.empresa_codigo_hidroviario
    ADD CONSTRAINT codigo_empresa_hidroviario_regiao_codigo FOREIGN KEY (regiao_codigo) REFERENCES geral.regiao(codigo) ON UPDATE CASCADE;


--
-- Name: embarcacao embarcacao_cor_principal_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_cor_principal_nome_fkey FOREIGN KEY (cor_principal_nome) REFERENCES geral.cor(nome);


--
-- Name: embarcacao embarcacao_cor_secundaria_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_cor_secundaria_nome_fkey FOREIGN KEY (cor_secundaria_nome) REFERENCES geral.cor(nome);


--
-- Name: embarcacao embarcacao_empresa_codigo_hidroviario_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_empresa_codigo_hidroviario_codigo_fkey FOREIGN KEY (empresa_codigo_hidroviario_codigo) REFERENCES concessao.empresa_codigo_hidroviario(codigo);


--
-- Name: embarcacao embarcacao_material_casco_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_material_casco_nome_fkey FOREIGN KEY (embarcacao_material_casco_nome) REFERENCES concessao.embarcacao_material_casco(nome);


--
-- Name: embarcacao embarcacao_modelo_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_modelo_nome_fkey FOREIGN KEY (embarcacao_modelo_nome) REFERENCES concessao.embarcacao_modelo(nome);


--
-- Name: embarcacao embarcacao_qualidade_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_qualidade_nome_fkey FOREIGN KEY (embarcacao_qualidade_nome) REFERENCES concessao.embarcacao_qualidade(nome);


--
-- Name: embarcacao embarcacao_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_tipo_nome_fkey FOREIGN KEY (embarcacao_tipo_nome) REFERENCES concessao.embarcacao_tipo(nome);


--
-- Name: embarcacao embarcacao_veiculo_combustivel_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.embarcacao
    ADD CONSTRAINT embarcacao_veiculo_combustivel_nome_fkey FOREIGN KEY (veiculo_combustivel_nome) REFERENCES geral.veiculo_combustivel(nome);


--
-- Name: empresa_codigo_hidroviario empresa_codigo_hidroviario_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.empresa_codigo_hidroviario
    ADD CONSTRAINT empresa_codigo_hidroviario_empresa_cnpj_fkey FOREIGN KEY (empresa_hidroviario_cnpj) REFERENCES concessao.empresa_hidroviario(cnpj) ON UPDATE CASCADE;


--
-- Name: empresa_hidroviario_diretor empresa_hidroviario_cnpj_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.empresa_hidroviario_diretor
    ADD CONSTRAINT empresa_hidroviario_cnpj_fkey FOREIGN KEY (empresa_hidroviario_cnpj) REFERENCES concessao.empresa_hidroviario(cnpj);


--
-- Name: secao_tarifaria fim_itinerario_id_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.secao_tarifaria
    ADD CONSTRAINT fim_itinerario_id_fkey FOREIGN KEY (fim_itinerario_id) REFERENCES concessao.itinerario(itinerario_id) ON UPDATE CASCADE;


--
-- Name: horario_hidroviario horario_hidroviario_linha_hidroviario_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario_hidroviario
    ADD CONSTRAINT horario_hidroviario_linha_hidroviario_codigo FOREIGN KEY (linha_hidroviario_codigo) REFERENCES concessao.linha_hidroviario(codigo) ON UPDATE CASCADE;


--
-- Name: horario horario_linha_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario
    ADD CONSTRAINT horario_linha_codigo FOREIGN KEY (linha_codigo) REFERENCES concessao.linha(codigo) ON UPDATE CASCADE;


--
-- Name: horario_verao horario_verao_linha_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.horario_verao
    ADD CONSTRAINT horario_verao_linha_codigo FOREIGN KEY (linha_codigo) REFERENCES concessao.linha(codigo) ON UPDATE CASCADE;


--
-- Name: secao_tarifaria inicio_itinerario_id_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.secao_tarifaria
    ADD CONSTRAINT inicio_itinerario_id_fkey FOREIGN KEY (inicio_itinerario_id) REFERENCES concessao.itinerario(itinerario_id) ON UPDATE CASCADE;


--
-- Name: itinerario_hidroviario itinerario_hidroviario_linha_hidroviario_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_hidroviario
    ADD CONSTRAINT itinerario_hidroviario_linha_hidroviario_codigo FOREIGN KEY (linha_hidroviario_codigo) REFERENCES concessao.linha_hidroviario(codigo) ON UPDATE CASCADE;


--
-- Name: itinerario_hidroviario itinerario_hidroviario_municipio_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_hidroviario
    ADD CONSTRAINT itinerario_hidroviario_municipio_nome_fkey FOREIGN KEY (municipio_nome) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: itinerario itinerario_linha_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario
    ADD CONSTRAINT itinerario_linha_codigo FOREIGN KEY (linha_codigo) REFERENCES concessao.linha(codigo) ON UPDATE CASCADE;


--
-- Name: itinerario itinerario_municipio_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario
    ADD CONSTRAINT itinerario_municipio_nome_fkey FOREIGN KEY (municipio_nome) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: itinerario_verao itinerario_verao_linha_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_verao
    ADD CONSTRAINT itinerario_verao_linha_codigo FOREIGN KEY (linha_codigo) REFERENCES concessao.linha(codigo) ON UPDATE CASCADE;


--
-- Name: itinerario_verao iv_municipio_nome_fk; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.itinerario_verao
    ADD CONSTRAINT iv_municipio_nome_fk FOREIGN KEY (municipio_nome) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: linha linha_eixo_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_eixo_nome_fkey FOREIGN KEY (eixo_nome) REFERENCES concessao.eixo(nome) ON UPDATE CASCADE;


--
-- Name: linha linha_empresa_codigo; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_empresa_codigo FOREIGN KEY (empresa_codigo_codigo) REFERENCES geral.empresa_codigo(codigo) ON UPDATE CASCADE;


--
-- Name: linha_hidroviario linha_hidroviario_eixo_nome_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_eixo_nome_fkey FOREIGN KEY (eixo_nome) REFERENCES concessao.eixo(nome) ON UPDATE CASCADE;


--
-- Name: linha_hidroviario linha_hidroviario_empresa_codigo_hidroviario_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_empresa_codigo_hidroviario_codigo_fkey FOREIGN KEY (empresa_codigo_hidroviario_codigo) REFERENCES concessao.empresa_codigo_hidroviario(codigo);


--
-- Name: linha_hidroviario linha_hidroviario_linha_caracteristica_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_linha_caracteristica_fkey FOREIGN KEY (linha_caracteristica_nome) REFERENCES concessao.linha_caracteristica(nome) ON UPDATE CASCADE;


--
-- Name: linha_hidroviario linha_hidroviario_linha_hidroviario_principal_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_linha_hidroviario_principal_codigo_fkey FOREIGN KEY (linha_codigo_principal) REFERENCES concessao.linha_hidroviario(codigo);


--
-- Name: linha_hidroviario linha_hidroviario_linha_modalidade_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_linha_modalidade_fkey FOREIGN KEY (linha_modalidade_nome) REFERENCES concessao.linha_modalidade(nome) ON UPDATE CASCADE;


--
-- Name: linha_hidroviario linha_hidroviario_linha_servico_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_linha_servico_fkey FOREIGN KEY (linha_servico_nome) REFERENCES concessao.linha_servico(nome) ON UPDATE CASCADE;


--
-- Name: linha_hidroviario linha_hidroviario_municipio_nome_destino_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_municipio_nome_destino_fkey FOREIGN KEY (municipio_nome_destino) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: linha_hidroviario linha_hidroviario_municipio_nome_origem_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha_hidroviario
    ADD CONSTRAINT linha_hidroviario_municipio_nome_origem_fkey FOREIGN KEY (municipio_nome_origem) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: linha linha_linha_caracteristica_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_linha_caracteristica_fkey FOREIGN KEY (linha_caracteristica_nome) REFERENCES concessao.linha_caracteristica(nome) ON UPDATE CASCADE;


--
-- Name: linha linha_linha_codigo_principal; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_linha_codigo_principal FOREIGN KEY (codigo) REFERENCES concessao.linha(codigo) ON UPDATE CASCADE;


--
-- Name: linha linha_linha_modalidade_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_linha_modalidade_fkey FOREIGN KEY (linha_modalidade_nome) REFERENCES concessao.linha_modalidade(nome) ON UPDATE CASCADE;


--
-- Name: linha linha_linha_servico_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_linha_servico_fkey FOREIGN KEY (linha_servico_nome) REFERENCES concessao.linha_servico(nome) ON UPDATE CASCADE;


--
-- Name: linha linha_municipio_nome_destino_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_municipio_nome_destino_fkey FOREIGN KEY (municipio_nome_destino) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: linha linha_municipio_nome_origem_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT linha_municipio_nome_origem_fkey FOREIGN KEY (municipio_nome_origem) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: ordem_servico__linha ordem_servico__linha_linha_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico__linha
    ADD CONSTRAINT ordem_servico__linha_linha_codigo_fkey FOREIGN KEY (linha_codigo) REFERENCES concessao.linha(codigo) ON UPDATE CASCADE;


--
-- Name: ordem_servico__linha ordem_servico__linha_ordem_servico_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico__linha
    ADD CONSTRAINT ordem_servico__linha_ordem_servico_codigo_fkey FOREIGN KEY (ordem_servico_numero) REFERENCES concessao.ordem_servico(numero) ON UPDATE CASCADE;


--
-- Name: ordem_servico ordem_servico_assunto_descricao; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico
    ADD CONSTRAINT ordem_servico_assunto_descricao FOREIGN KEY (ordem_servico_assunto_descricao) REFERENCES concessao.ordem_servico_assunto(descricao);


--
-- Name: ordem_servico_hidroviario ordem_servico_assunto_descricao; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico_hidroviario
    ADD CONSTRAINT ordem_servico_assunto_descricao FOREIGN KEY (ordem_servico_assunto_descricao) REFERENCES concessao.ordem_servico_assunto(descricao);


--
-- Name: ordem_servico_hidroviario__linha_hidroviario ordem_servico_hidro__linha_hidro_linha_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico_hidroviario__linha_hidroviario
    ADD CONSTRAINT ordem_servico_hidro__linha_hidro_linha_codigo_fkey FOREIGN KEY (linha_hidroviario_codigo) REFERENCES concessao.linha_hidroviario(codigo) ON UPDATE CASCADE;


--
-- Name: ordem_servico_hidroviario__linha_hidroviario ordem_servico_hidro__linha_hidro_os_hidro_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.ordem_servico_hidroviario__linha_hidroviario
    ADD CONSTRAINT ordem_servico_hidro__linha_hidro_os_hidro_codigo_fkey FOREIGN KEY (ordem_servico_hidroviario_numero) REFERENCES concessao.ordem_servico_hidroviario(numero) ON UPDATE CASCADE;


--
-- Name: parecer_tecnico parecer_tecnico_linha_codigo_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.parecer_tecnico
    ADD CONSTRAINT parecer_tecnico_linha_codigo_fkey FOREIGN KEY (linha_codigo) REFERENCES concessao.linha(codigo) ON UPDATE CASCADE;


--
-- Name: parecer_tecnico parecer_tecnico_ordem_servico_assunto_descricao_FKEY; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.parecer_tecnico
    ADD CONSTRAINT "parecer_tecnico_ordem_servico_assunto_descricao_FKEY" FOREIGN KEY (ordem_servico_assunto_descricao) REFERENCES concessao.ordem_servico_assunto(descricao);


--
-- Name: linha veiculo_qualidade_fkey; Type: FK CONSTRAINT; Schema: concessao; Owner: metroplan
--

ALTER TABLE ONLY concessao.linha
    ADD CONSTRAINT veiculo_qualidade_fkey FOREIGN KEY (veiculo_qualidade_nome) REFERENCES geral.veiculo_qualidade(nome);


--
-- Name: documento documento_documento_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento
    ADD CONSTRAINT documento_documento_tipo_nome_fkey FOREIGN KEY (documento_tipo_nome) REFERENCES eventual.documento_tipo(nome);


--
-- Name: documento_empresa documento_empresa_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_empresa
    ADD CONSTRAINT documento_empresa_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj);


--
-- Name: documento_empresa documento_empresa_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_empresa
    ADD CONSTRAINT documento_empresa_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- Name: documento documento_fluxo_pendencia_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento
    ADD CONSTRAINT documento_fluxo_pendencia_fkey FOREIGN KEY (fluxo_pendencia_id) REFERENCES eventual.fluxo_pendencia(id) ON DELETE SET NULL;


--
-- Name: documento_motorista documento_motorista_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_motorista
    ADD CONSTRAINT documento_motorista_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- Name: documento_motorista documento_motorista_motorista_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_motorista
    ADD CONSTRAINT documento_motorista_motorista_id_fkey FOREIGN KEY (motorista_id) REFERENCES eventual.motorista(id);


--
-- Name: documento_tipo_permissao documento_tipo_permissao_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_tipo_permissao
    ADD CONSTRAINT documento_tipo_permissao_tipo_nome_fkey FOREIGN KEY (tipo_nome) REFERENCES eventual.documento_tipo(nome);


--
-- Name: documento_usuario documento_usuario_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_usuario
    ADD CONSTRAINT documento_usuario_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- Name: documento_usuario documento_usuario_usuario_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_usuario
    ADD CONSTRAINT documento_usuario_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES web.usuario(id);


--
-- Name: documento_veiculo documento_veiculo_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_veiculo
    ADD CONSTRAINT documento_veiculo_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- Name: documento_veiculo documento_veiculo_veiculo_placa_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_veiculo
    ADD CONSTRAINT documento_veiculo_veiculo_placa_fkey FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa);


--
-- Name: documento_viagem documento_viagem_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_viagem
    ADD CONSTRAINT documento_viagem_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- Name: documento_viagem documento_viagem_viagem_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.documento_viagem
    ADD CONSTRAINT documento_viagem_viagem_id_fkey FOREIGN KEY (viagem_id) REFERENCES eventual.viagem(id);


--
-- Name: fluxo_pendencia fluxo_pendencia_analista_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_analista_fkey FOREIGN KEY (analista) REFERENCES web.usuario(email);


--
-- Name: fluxo_pendencia fluxo_pendencia_entidade_tipo_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_entidade_tipo_fkey FOREIGN KEY (entidade_tipo) REFERENCES eventual.tipo_entidade_pendencia(tipo);


--
-- Name: fluxo_pendencia fluxo_pendencia_status_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_status_fkey FOREIGN KEY (status) REFERENCES eventual.status_pendencia(status);


--
-- Name: motorista motorista_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.motorista
    ADD CONSTRAINT motorista_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj);


--
-- Name: passageiro passageiro_viagem_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.passageiro
    ADD CONSTRAINT passageiro_viagem_id_fkey FOREIGN KEY (viagem_id) REFERENCES eventual.viagem(id) ON DELETE CASCADE;


--
-- Name: viagem viagem_motorista_aux_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_motorista_aux_id_fkey FOREIGN KEY (motorista_aux_id) REFERENCES eventual.motorista(id);


--
-- Name: viagem viagem_motorista_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_motorista_id_fkey FOREIGN KEY (motorista_id) REFERENCES eventual.motorista(id);


--
-- Name: viagem viagem_municipio_destino_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_municipio_destino_fkey FOREIGN KEY (municipio_destino) REFERENCES geral.municipio(nome);


--
-- Name: viagem viagem_municipio_origem_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_municipio_origem_fkey FOREIGN KEY (municipio_origem) REFERENCES geral.municipio(nome);


--
-- Name: viagem viagem_regiao_codigo_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_regiao_codigo_fkey FOREIGN KEY (regiao_codigo) REFERENCES geral.regiao(codigo);


--
-- Name: viagem viagem_veiculo_placa_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_veiculo_placa_fkey FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa);


--
-- Name: viagem viagem_viagem_tipo_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: postgres
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_viagem_tipo_fkey FOREIGN KEY (viagem_tipo) REFERENCES eventual.viagem_tipo(nome);


--
-- Name: autorizacao autorizacao_codigo_barras_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao
    ADD CONSTRAINT autorizacao_codigo_barras_fkey FOREIGN KEY (codigo_barras) REFERENCES fretamento.codigo_barras(codigo) ON UPDATE CASCADE;


--
-- Name: autorizacao autorizacao_contrato_codigo_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao
    ADD CONSTRAINT autorizacao_contrato_codigo_fkey FOREIGN KEY (contrato_codigo) REFERENCES fretamento.contrato(codigo) ON UPDATE CASCADE;


--
-- Name: autorizacao_emitida autorizacao_emitida_usuario_nome_fk; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao_emitida
    ADD CONSTRAINT autorizacao_emitida_usuario_nome_fk FOREIGN KEY (usuario_nome) REFERENCES admin.usuario(nome);


--
-- Name: autorizacao autorizacao_empresa_cnpj_sublocacao; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao
    ADD CONSTRAINT autorizacao_empresa_cnpj_sublocacao FOREIGN KEY (empresa_cnpj_sublocacao) REFERENCES geral.empresa(cnpj);


--
-- Name: autorizacao autorizacao_veiculo_placa_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao
    ADD CONSTRAINT autorizacao_veiculo_placa_fkey FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE;


--
-- Name: contratante contratantes_identificacao_nome_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contratante
    ADD CONSTRAINT contratantes_identificacao_nome_fkey FOREIGN KEY (identificacao_nome) REFERENCES fretamento.identificacao(nome) ON UPDATE CASCADE;


--
-- Name: contratante contratantes_municipio_nome_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contratante
    ADD CONSTRAINT contratantes_municipio_nome_fkey FOREIGN KEY (municipio_nome) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: autorizacao_emitida contrato_codigo_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao_emitida
    ADD CONSTRAINT contrato_codigo_fkey FOREIGN KEY (contrato_codigo) REFERENCES fretamento.contrato(codigo);


--
-- Name: contrato contrato_contratante_codigo_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato
    ADD CONSTRAINT contrato_contratante_codigo_fkey FOREIGN KEY (contratante_codigo) REFERENCES fretamento.contratante(codigo) ON UPDATE CASCADE;


--
-- Name: contrato contrato_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato
    ADD CONSTRAINT contrato_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj) ON UPDATE CASCADE;


--
-- Name: contrato_itinerario contrato_itinerario_placa_fk; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato_itinerario
    ADD CONSTRAINT contrato_itinerario_placa_fk FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE;


--
-- Name: contrato contrato_regiao_codigo_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato
    ADD CONSTRAINT contrato_regiao_codigo_fkey FOREIGN KEY (regiao_codigo) REFERENCES geral.regiao(codigo);


--
-- Name: contrato contrato_servico_nome_fk; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato
    ADD CONSTRAINT contrato_servico_nome_fk FOREIGN KEY (servico_nome) REFERENCES fretamento.servico(nome) ON UPDATE CASCADE;


--
-- Name: contrato entidade_estudantil_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato
    ADD CONSTRAINT entidade_estudantil_fkey FOREIGN KEY (entidade_estudantil) REFERENCES fretamento.entidade(nome);


--
-- Name: guia guia_empresa_cnpj; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.guia
    ADD CONSTRAINT guia_empresa_cnpj FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj);


--
-- Name: hlp hlp_contrato_codigo_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.hlp
    ADD CONSTRAINT hlp_contrato_codigo_fkey FOREIGN KEY (contrato_codigo) REFERENCES fretamento.contrato(codigo);


--
-- Name: hlpa hlpa_hlp_id_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.hlpa
    ADD CONSTRAINT hlpa_hlp_id_fkey FOREIGN KEY (hlp_id) REFERENCES fretamento.hlp(id);


--
-- Name: contrato_itinerario itinerario_contrato_id_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato_itinerario
    ADD CONSTRAINT itinerario_contrato_id_fkey FOREIGN KEY (contrato_codigo) REFERENCES fretamento.contrato(codigo) ON UPDATE CASCADE;


--
-- Name: contrato_itinerario itinerario_municipio_nome_chegada_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato_itinerario
    ADD CONSTRAINT itinerario_municipio_nome_chegada_fkey FOREIGN KEY (municipio_nome_chegada) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: contrato_itinerario itinerario_municipio_nome_saida_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.contrato_itinerario
    ADD CONSTRAINT itinerario_municipio_nome_saida_fkey FOREIGN KEY (municipio_nome_saida) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: lista_passageiros lista_passageiros_contrato_codigo_fk; Type: FK CONSTRAINT; Schema: fretamento; Owner: postgres
--

ALTER TABLE ONLY fretamento.lista_passageiros
    ADD CONSTRAINT lista_passageiros_contrato_codigo_fk FOREIGN KEY (contrato_codigo) REFERENCES fretamento.contrato(codigo);


--
-- Name: qr qr_usuario_fk; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.qr
    ADD CONSTRAINT qr_usuario_fk FOREIGN KEY (usuario) REFERENCES admin.usuario(nome);


--
-- Name: qr qr_veiculo_placa_fk; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.qr
    ADD CONSTRAINT qr_veiculo_placa_fk FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: laudo_vistoria veiculo_placa_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.laudo_vistoria
    ADD CONSTRAINT veiculo_placa_fkey FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE;


--
-- Name: autorizacao_emitida veiculo_placa_fkey; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.autorizacao_emitida
    ADD CONSTRAINT veiculo_placa_fkey FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE;


--
-- Name: vencimento_seguradora vencimento_seguradora_nome; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.vencimento_seguradora
    ADD CONSTRAINT vencimento_seguradora_nome FOREIGN KEY (seguradora) REFERENCES fretamento.seguradora(nome);


--
-- Name: vencimento_seguradora vencimento_seguradora_placa_fk; Type: FK CONSTRAINT; Schema: fretamento; Owner: metroplan
--

ALTER TABLE ONLY fretamento.vencimento_seguradora
    ADD CONSTRAINT vencimento_seguradora_placa_fk FOREIGN KEY (placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: acordo__empresa acordo__empresa_acordo_codigo_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.acordo__empresa
    ADD CONSTRAINT acordo__empresa_acordo_codigo_fkey FOREIGN KEY (acordo_codigo) REFERENCES geral.acordo(codigo) ON UPDATE CASCADE;


--
-- Name: acordo__empresa acordo__empresa_empresa_codigo_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.acordo__empresa
    ADD CONSTRAINT acordo__empresa_empresa_codigo_fkey FOREIGN KEY (empresa_codigo) REFERENCES geral.empresa_codigo(codigo) ON UPDATE CASCADE;


--
-- Name: empresa_codigo codigo_empresa_regiao_codigo; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa_codigo
    ADD CONSTRAINT codigo_empresa_regiao_codigo FOREIGN KEY (regiao_codigo) REFERENCES geral.regiao(codigo) ON UPDATE CASCADE;


--
-- Name: empresa contratado_regiao_codigo_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa
    ADD CONSTRAINT contratado_regiao_codigo_fkey FOREIGN KEY (regiao_codigo) REFERENCES geral.regiao(codigo) ON UPDATE CASCADE;


--
-- Name: empresa_diretor empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa_diretor
    ADD CONSTRAINT empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj) ON UPDATE CASCADE;


--
-- Name: veiculo empresa_codigo_codigo_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT empresa_codigo_codigo_fkey FOREIGN KEY (empresa_codigo_codigo) REFERENCES geral.empresa_codigo(codigo);


--
-- Name: empresa_codigo empresa_codigo_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa_codigo
    ADD CONSTRAINT empresa_codigo_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj) ON UPDATE CASCADE;


--
-- Name: empresa empresa_municipio_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.empresa
    ADD CONSTRAINT empresa_municipio_fkey FOREIGN KEY (municipio_nome) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: logradouro logradouro_municipio_nome_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.logradouro
    ADD CONSTRAINT logradouro_municipio_nome_fkey FOREIGN KEY (municipio_nome) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: municipio municipio_regiao_codigo_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.municipio
    ADD CONSTRAINT municipio_regiao_codigo_fkey FOREIGN KEY (regiao_codigo) REFERENCES geral.regiao(codigo);


--
-- Name: veiculo validador_be_numero_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT validador_be_numero_fkey FOREIGN KEY (validador_be_numero) REFERENCES geral.validador_be(numero);


--
-- Name: veiculo veiculo_acordo_codigo_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_acordo_codigo_fkey FOREIGN KEY (acordo_codigo) REFERENCES geral.empresa_codigo(codigo);


--
-- Name: veiculo veiculo_carroceria_nome_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_carroceria_nome_fkey FOREIGN KEY (veiculo_carroceria_nome) REFERENCES geral.veiculo_carroceria(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_chassi_nome_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_chassi_nome_fkey FOREIGN KEY (veiculo_chassi_nome) REFERENCES geral.veiculo_chassi(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_classificacao_inmetro_nome_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_classificacao_inmetro_nome_fkey FOREIGN KEY (classificacao_inmetro_nome) REFERENCES geral.classificacao_inmetro(nome);


--
-- Name: veiculo veiculo_combustivel_nome_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_combustivel_nome_fkey FOREIGN KEY (veiculo_combustivel_nome) REFERENCES geral.veiculo_combustivel(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_concessao_veiculo_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_concessao_veiculo_tipo_nome_fkey FOREIGN KEY (concessao_veiculo_tipo_nome) REFERENCES concessao.concessao_veiculo_tipo(nome);


--
-- Name: veiculo veiculo_cor1_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_cor1_fkey FOREIGN KEY (cor_principal_nome) REFERENCES geral.cor(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_cor2_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_cor2_fkey FOREIGN KEY (cor_secundaria_nome) REFERENCES geral.cor(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_fretamento_veiculo_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_fretamento_veiculo_tipo_nome_fkey FOREIGN KEY (fretamento_veiculo_tipo_nome) REFERENCES fretamento.fretamento_veiculo_tipo(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_seguradora_fk; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_seguradora_fk FOREIGN KEY (seguradora) REFERENCES fretamento.seguradora(nome);


--
-- Name: veiculo veiculo_veiculo_motor_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_veiculo_motor_fkey FOREIGN KEY (veiculo_motor_nome) REFERENCES geral.veiculo_motor(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_veiculo_qualidade_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_veiculo_qualidade_fkey FOREIGN KEY (veiculo_qualidade_nome) REFERENCES geral.veiculo_qualidade(nome) ON UPDATE CASCADE;


--
-- Name: veiculo veiculo_veiculo_rodados_fkey; Type: FK CONSTRAINT; Schema: geral; Owner: metroplan
--

ALTER TABLE ONLY geral.veiculo
    ADD CONSTRAINT veiculo_veiculo_rodados_fkey FOREIGN KEY (veiculo_rodados_nome) REFERENCES geral.veiculo_rodados(nome);


--
-- Name: motorista motorista_empresa_cnpj_fk; Type: FK CONSTRAINT; Schema: motorista; Owner: metroplan
--

ALTER TABLE ONLY motorista.motorista
    ADD CONSTRAINT motorista_empresa_cnpj_fk FOREIGN KEY (empresa_cnpj) REFERENCES motorista.empresa(cnpj) ON UPDATE CASCADE;


--
-- Name: usuario usuario_empresa_cnpj_fk; Type: FK CONSTRAINT; Schema: motorista; Owner: metroplan
--

ALTER TABLE ONLY motorista.usuario
    ADD CONSTRAINT usuario_empresa_cnpj_fk FOREIGN KEY (empresa_cnpj) REFERENCES motorista.empresa(cnpj) ON UPDATE CASCADE;


--
-- Name: auto auto_fiscal_matricula; Type: FK CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.auto
    ADD CONSTRAINT auto_fiscal_matricula FOREIGN KEY (fiscal_matricula) REFERENCES multas.fiscal(matricula) ON UPDATE CASCADE;


--
-- Name: auto auto_penalidade_pk; Type: FK CONSTRAINT; Schema: multas; Owner: metroplan
--

ALTER TABLE ONLY multas.auto
    ADD CONSTRAINT auto_penalidade_pk FOREIGN KEY (penalidade_subgrupo) REFERENCES multas.penalidade(subgrupo);


--
-- Name: ocorrencia assunto_nome_fkey; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT assunto_nome_fkey FOREIGN KEY (ocorrencia_assunto_nome) REFERENCES saac.ocorrencia_assunto(nome) ON UPDATE CASCADE;


--
-- Name: ocorrencia ocorrencia_empresa_codigo_fkey; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT ocorrencia_empresa_codigo_fkey FOREIGN KEY (empresa_codigo) REFERENCES geral.empresa_codigo(codigo) ON UPDATE CASCADE;


--
-- Name: ocorrencia ocorrencia_municipio_fkey; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT ocorrencia_municipio_fkey FOREIGN KEY (municipio_nome_ocorrencia) REFERENCES geral.municipio(nome) ON UPDATE CASCADE;


--
-- Name: ocorrencia ocorrencia_tipo_nome; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT ocorrencia_tipo_nome FOREIGN KEY (ocorrencia_tipo_nome) REFERENCES saac.ocorrencia_tipo(nome) ON UPDATE CASCADE;


--
-- Name: ocorrencia ocorrencia_veiculo_placa; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT ocorrencia_veiculo_placa FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa) ON UPDATE CASCADE;


--
-- Name: andamento saac_andamento_departamento_fk; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.andamento
    ADD CONSTRAINT saac_andamento_departamento_fk FOREIGN KEY (departamento_nome) REFERENCES saac.departamento(nome);


--
-- Name: ocorrencia saac_ocorrencia_assunto_nome_fk; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT saac_ocorrencia_assunto_nome_fk FOREIGN KEY (ocorrencia_assunto_nome) REFERENCES saac.ocorrencia_assunto(nome);


--
-- Name: ocorrencia_assunto saac_ocorrencia_assunto_tipo_nome_fk; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia_assunto
    ADD CONSTRAINT saac_ocorrencia_assunto_tipo_nome_fk FOREIGN KEY (ocorrencia_assunto_tipo_nome) REFERENCES saac.ocorrencia_assunto_tipo(nome);


--
-- Name: ocorrencia servico_nome; Type: FK CONSTRAINT; Schema: saac; Owner: metroplan
--

ALTER TABLE ONLY saac.ocorrencia
    ADD CONSTRAINT servico_nome FOREIGN KEY (ocorrencia_servico_nome) REFERENCES saac.ocorrencia_servico(nome) ON UPDATE CASCADE;


--
-- Name: token_validacao_email token_validacao_email_usuario_id_fkey; Type: FK CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.token_validacao_email
    ADD CONSTRAINT token_validacao_email_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES web.usuario(id) ON DELETE CASCADE;


--
-- Name: usuario usuario_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj);


--
-- Name: usuario usuario_papel_nome_fkey; Type: FK CONSTRAINT; Schema: web; Owner: postgres
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_papel_nome_fkey FOREIGN KEY (papel_nome) REFERENCES web.papel(nome);


--
-- PostgreSQL database dump complete
--

