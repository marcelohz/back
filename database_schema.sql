--
-- PostgreSQL database dump
--

-- Dumped from database version 14.18
-- Dumped by pg_dump version 17.0

-- Started on 2026-03-02 14:35:23

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 18 (class 2615 OID 796583)
-- Name: eventual; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA eventual;


--
-- TOC entry 21 (class 2615 OID 799606)
-- Name: web; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA web;


--
-- TOC entry 708 (class 1255 OID 816851)
-- Name: avancar_pendencia(integer, text, text, text); Type: FUNCTION; Schema: eventual; Owner: -
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


--
-- TOC entry 707 (class 1255 OID 816845)
-- Name: fn_analista_obrigatorio(); Type: FUNCTION; Schema: eventual; Owner: -
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


--
-- TOC entry 704 (class 1255 OID 816843)
-- Name: fn_evitar_status_repetido(); Type: FUNCTION; Schema: eventual; Owner: -
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


--
-- TOC entry 705 (class 1255 OID 816935)
-- Name: fn_motivo_obrigatorio(); Type: FUNCTION; Schema: eventual; Owner: -
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


--
-- TOC entry 703 (class 1255 OID 816841)
-- Name: fn_valida_entidade(); Type: FUNCTION; Schema: eventual; Owner: -
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


--
-- TOC entry 706 (class 1255 OID 816852)
-- Name: normalizar_email_usuario(); Type: FUNCTION; Schema: web; Owner: -
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 436 (class 1259 OID 800010)
-- Name: documento; Type: TABLE; Schema: eventual; Owner: -
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


--
-- TOC entry 437 (class 1259 OID 800024)
-- Name: documento_empresa; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.documento_empresa (
    id integer NOT NULL,
    empresa_cnpj text NOT NULL
);


--
-- TOC entry 435 (class 1259 OID 800009)
-- Name: documento_id_seq; Type: SEQUENCE; Schema: eventual; Owner: -
--

CREATE SEQUENCE eventual.documento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4327 (class 0 OID 0)
-- Dependencies: 435
-- Name: documento_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: -
--

ALTER SEQUENCE eventual.documento_id_seq OWNED BY eventual.documento.id;


--
-- TOC entry 444 (class 1259 OID 800210)
-- Name: documento_motorista; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.documento_motorista (
    id integer NOT NULL,
    motorista_id integer NOT NULL
);


--
-- TOC entry 443 (class 1259 OID 800209)
-- Name: documento_motorista_id_seq; Type: SEQUENCE; Schema: eventual; Owner: -
--

CREATE SEQUENCE eventual.documento_motorista_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4328 (class 0 OID 0)
-- Dependencies: 443
-- Name: documento_motorista_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: -
--

ALTER SEQUENCE eventual.documento_motorista_id_seq OWNED BY eventual.documento_motorista.id;


--
-- TOC entry 434 (class 1259 OID 800002)
-- Name: documento_tipo; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.documento_tipo (
    nome text NOT NULL,
    descricao text
);


--
-- TOC entry 440 (class 1259 OID 800073)
-- Name: documento_tipo_permissao; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.documento_tipo_permissao (
    tipo_nome text NOT NULL,
    entidade_tipo text NOT NULL,
    CONSTRAINT documento_tipo_permissao_entidade_tipo_check CHECK ((entidade_tipo = ANY (ARRAY['empresa'::text, 'usuario'::text, 'veiculo'::text])))
);


--
-- TOC entry 438 (class 1259 OID 800041)
-- Name: documento_usuario; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.documento_usuario (
    id integer NOT NULL,
    usuario_id integer NOT NULL
);


--
-- TOC entry 439 (class 1259 OID 800056)
-- Name: documento_veiculo; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.documento_veiculo (
    id integer NOT NULL,
    veiculo_placa text NOT NULL
);


--
-- TOC entry 450 (class 1259 OID 808150)
-- Name: documento_viagem; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.documento_viagem (
    id integer NOT NULL,
    viagem_id integer NOT NULL
);


--
-- TOC entry 456 (class 1259 OID 816815)
-- Name: fluxo_pendencia; Type: TABLE; Schema: eventual; Owner: -
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


--
-- TOC entry 455 (class 1259 OID 816814)
-- Name: fluxo_pendencia_id_seq; Type: SEQUENCE; Schema: eventual; Owner: -
--

CREATE SEQUENCE eventual.fluxo_pendencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4329 (class 0 OID 0)
-- Dependencies: 455
-- Name: fluxo_pendencia_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: -
--

ALTER SEQUENCE eventual.fluxo_pendencia_id_seq OWNED BY eventual.fluxo_pendencia.id;


--
-- TOC entry 442 (class 1259 OID 800195)
-- Name: motorista; Type: TABLE; Schema: eventual; Owner: -
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


--
-- TOC entry 441 (class 1259 OID 800194)
-- Name: motorista_id_seq; Type: SEQUENCE; Schema: eventual; Owner: -
--

CREATE SEQUENCE eventual.motorista_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4330 (class 0 OID 0)
-- Dependencies: 441
-- Name: motorista_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: -
--

ALTER SEQUENCE eventual.motorista_id_seq OWNED BY eventual.motorista.id;


--
-- TOC entry 449 (class 1259 OID 808120)
-- Name: passageiro; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.passageiro (
    id integer NOT NULL,
    viagem_id integer NOT NULL,
    nome text NOT NULL,
    cpf text NOT NULL
);


--
-- TOC entry 448 (class 1259 OID 808119)
-- Name: passageiro_id_seq; Type: SEQUENCE; Schema: eventual; Owner: -
--

CREATE SEQUENCE eventual.passageiro_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4331 (class 0 OID 0)
-- Dependencies: 448
-- Name: passageiro_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: -
--

ALTER SEQUENCE eventual.passageiro_id_seq OWNED BY eventual.passageiro.id;


--
-- TOC entry 453 (class 1259 OID 816800)
-- Name: status_pendencia; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.status_pendencia (
    status text NOT NULL,
    nome text NOT NULL
);


--
-- TOC entry 454 (class 1259 OID 816807)
-- Name: tipo_entidade_pendencia; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.tipo_entidade_pendencia (
    tipo text NOT NULL,
    descricao text NOT NULL
);


--
-- TOC entry 457 (class 1259 OID 816847)
-- Name: v_pendencia_atual; Type: VIEW; Schema: eventual; Owner: -
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


--
-- TOC entry 447 (class 1259 OID 808062)
-- Name: viagem; Type: TABLE; Schema: eventual; Owner: -
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


--
-- TOC entry 446 (class 1259 OID 808061)
-- Name: viagem_id_seq; Type: SEQUENCE; Schema: eventual; Owner: -
--

CREATE SEQUENCE eventual.viagem_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4332 (class 0 OID 0)
-- Dependencies: 446
-- Name: viagem_id_seq; Type: SEQUENCE OWNED BY; Schema: eventual; Owner: -
--

ALTER SEQUENCE eventual.viagem_id_seq OWNED BY eventual.viagem.id;


--
-- TOC entry 445 (class 1259 OID 808001)
-- Name: viagem_tipo; Type: TABLE; Schema: eventual; Owner: -
--

CREATE TABLE eventual.viagem_tipo (
    nome text NOT NULL
);


--
-- TOC entry 431 (class 1259 OID 799650)
-- Name: papel; Type: TABLE; Schema: web; Owner: -
--

CREATE TABLE web.papel (
    nome text NOT NULL
);


--
-- TOC entry 452 (class 1259 OID 816620)
-- Name: token_validacao_email; Type: TABLE; Schema: web; Owner: -
--

CREATE TABLE web.token_validacao_email (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    token text NOT NULL,
    criado_em timestamp without time zone DEFAULT now() NOT NULL,
    expira_em timestamp without time zone NOT NULL
);


--
-- TOC entry 451 (class 1259 OID 816619)
-- Name: token_validacao_email_id_seq; Type: SEQUENCE; Schema: web; Owner: -
--

CREATE SEQUENCE web.token_validacao_email_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4333 (class 0 OID 0)
-- Dependencies: 451
-- Name: token_validacao_email_id_seq; Type: SEQUENCE OWNED BY; Schema: web; Owner: -
--

ALTER SEQUENCE web.token_validacao_email_id_seq OWNED BY web.token_validacao_email.id;


--
-- TOC entry 433 (class 1259 OID 799667)
-- Name: usuario; Type: TABLE; Schema: web; Owner: -
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


--
-- TOC entry 432 (class 1259 OID 799666)
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: web; Owner: -
--

CREATE SEQUENCE web.usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4334 (class 0 OID 0)
-- Dependencies: 432
-- Name: usuario_id_seq; Type: SEQUENCE OWNED BY; Schema: web; Owner: -
--

ALTER SEQUENCE web.usuario_id_seq OWNED BY web.usuario.id;


--
-- TOC entry 4026 (class 2604 OID 800013)
-- Name: documento id; Type: DEFAULT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento ALTER COLUMN id SET DEFAULT nextval('eventual.documento_id_seq'::regclass);


--
-- TOC entry 4030 (class 2604 OID 800213)
-- Name: documento_motorista id; Type: DEFAULT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_motorista ALTER COLUMN id SET DEFAULT nextval('eventual.documento_motorista_id_seq'::regclass);


--
-- TOC entry 4035 (class 2604 OID 816818)
-- Name: fluxo_pendencia id; Type: DEFAULT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.fluxo_pendencia ALTER COLUMN id SET DEFAULT nextval('eventual.fluxo_pendencia_id_seq'::regclass);


--
-- TOC entry 4028 (class 2604 OID 800198)
-- Name: motorista id; Type: DEFAULT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.motorista ALTER COLUMN id SET DEFAULT nextval('eventual.motorista_id_seq'::regclass);


--
-- TOC entry 4032 (class 2604 OID 808123)
-- Name: passageiro id; Type: DEFAULT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.passageiro ALTER COLUMN id SET DEFAULT nextval('eventual.passageiro_id_seq'::regclass);


--
-- TOC entry 4031 (class 2604 OID 808065)
-- Name: viagem id; Type: DEFAULT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem ALTER COLUMN id SET DEFAULT nextval('eventual.viagem_id_seq'::regclass);


--
-- TOC entry 4033 (class 2604 OID 816623)
-- Name: token_validacao_email id; Type: DEFAULT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.token_validacao_email ALTER COLUMN id SET DEFAULT nextval('web.token_validacao_email_id_seq'::regclass);


--
-- TOC entry 4021 (class 2604 OID 799670)
-- Name: usuario id; Type: DEFAULT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.usuario ALTER COLUMN id SET DEFAULT nextval('web.usuario_id_seq'::regclass);


--
-- TOC entry 4301 (class 0 OID 800010)
-- Dependencies: 436
-- Data for Name: documento; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento (id, documento_tipo_nome, caminho, tamanho, hash, data_upload, validade, fluxo_pendencia_id, aprovado_em) FROM stdin;
4	PROCURACAO	empresa/6565655665574_6565655665574_PROCURACAO.pdf	352289	7da2265e668a9d6b5d6234784ee0399a	2025-10-31 13:18:43.309846	\N	\N	\N
7	CRLV	veiculo/XXX4444_03929471000177_CRLV.pdf	1571490	a5814e0f09f1c6bc77509262794138a9	2025-11-03 14:15:31.814777	\N	\N	\N
8	CRLV	veiculo/BBB11111_03929471000177_CRLV.pdf	1571490	a5814e0f09f1c6bc77509262794138a9	2025-11-06 09:19:57.66288	\N	\N	\N
11	CRLV	veiculo/IBC2472_03929471000177_CRLV.pdf	1571490	a5814e0f09f1c6bc77509262794138a9	2025-11-06 10:44:49.40738	\N	\N	\N
12	CNH	motorista/03929471000177_1_CNH.pdf	2069294	3619e2f09a04cbbb94aa2e11cea82024	2025-11-06 14:14:55.401163	\N	\N	\N
25	IDENTIDADE_RESPONSAVEL	empresa/4545454545_4545454545_IDENTIDADE_RESPONSAVEL.pdf	2965412	ea34e6cac4e4e7a8b57646fe3cf44b85	2026-01-12 12:42:42.377497	\N	\N	\N
26	CONTRATO_SOCIAL	empresa/4545454545_4545454545_CONTRATO_SOCIAL.pdf	3413320	264a6f6c78ed030283d30fbb041092f0	2026-01-12 12:42:42.394821	\N	\N	\N
13	PROCURACAO	empresa/03929471000177_03929471000177_PROCURACAO.pdf	71870	d15a30a9678a2ef8d151c853c3f4f402	2025-11-10 08:07:47.479054	2025-12-16	\N	\N
9	CONTRATO_SOCIAL	empresa/03929471000177_03929471000177_CONTRATO_SOCIAL.pdf	2208728	d208e3403b7881a5a53930e448c5772f	2025-11-06 09:12:28.393023	2025-12-31	\N	\N
5	IDENTIDADE_RESPONSAVEL	empresa/03929471000177_03929471000177_IDENTIDADE_RESPONSAVEL.pdf	1046044	28b38d68d99412095462b1e3867b2bd5	2025-11-03 13:24:03.434819	2025-12-23	\N	\N
14	CONTRATO_SOCIAL	empresa/03929471000177_03929471000177_CONTRATO_SOCIAL.pdf	2069294	3619e2f09a04cbbb94aa2e11cea82024	2025-12-16 14:03:43.903988	\N	\N	\N
15	IDENTIDADE_RESPONSAVEL	empresa/03929471000177_03929471000177_IDENTIDADE_RESPONSAVEL.pdf	1046044	28b38d68d99412095462b1e3867b2bd5	2025-12-16 14:03:55.760314	\N	\N	\N
20	CONTRATO_SOCIAL	empresa/111111111111111_111111111111111_CONTRATO_SOCIAL.pdf	71870	d15a30a9678a2ef8d151c853c3f4f402	2026-01-06 11:38:41.103806	2026-01-01	56	2026-01-06 12:11:51.493939
16	IDENTIDADE_RESPONSAVEL	empresa/111111111111111_111111111111111_IDENTIDADE_RESPONSAVEL.pdf	352289	7da2265e668a9d6b5d6234784ee0399a	2025-12-16 14:04:29.785788	2026-02-02	56	2026-01-06 12:11:51.493939
21	CONTRATO_SOCIAL	empresa/87788931000184_87788931000184_CONTRATO_SOCIAL.pdf	2349939	4bcbcc010652c39c712eb5c8a87e2cfd	2026-01-07 14:21:21.488561	\N	\N	2025-12-29 09:44:32
22	IDENTIDADE_RESPONSAVEL	empresa/87788931000184_87788931000184_IDENTIDADE_RESPONSAVEL.pdf	504557	123a4a3629c2993bd853a714faf77802	2026-01-07 14:21:50.305799	\N	\N	2025-12-29 09:44:32
10	CRLV	veiculo/03929471000177_BBB11111_CRLV.pdf	352289	7da2265e668a9d6b5d6234784ee0399a	2025-11-10 08:09:11.771045	2025-12-31	62	\N
\.


--
-- TOC entry 4302 (class 0 OID 800024)
-- Dependencies: 437
-- Data for Name: documento_empresa; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento_empresa (id, empresa_cnpj) FROM stdin;
4	6565655665574
5	03929471000177
9	03929471000177
13	03929471000177
14	03929471000177
15	03929471000177
16	111111111111111
20	111111111111111
21	87788931000184
22	87788931000184
25	4545454545
26	4545454545
\.


--
-- TOC entry 4309 (class 0 OID 800210)
-- Dependencies: 444
-- Data for Name: documento_motorista; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento_motorista (id, motorista_id) FROM stdin;
12	1
\.


--
-- TOC entry 4299 (class 0 OID 800002)
-- Dependencies: 434
-- Data for Name: documento_tipo; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento_tipo (nome, descricao) FROM stdin;
IDENTIDADE_RESPONSAVEL	Documento de identidade do responsável
CONTRATO_SOCIAL	Contrato social da empresa
PROCURACAO	Procuração
CRLV	Certificado de Registro e Licenciamento de Veículo
CNH	Carteira Nacional de Habilitação
NOTA_FISCAL	Nota Fiscal
\.


--
-- TOC entry 4305 (class 0 OID 800073)
-- Dependencies: 440
-- Data for Name: documento_tipo_permissao; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento_tipo_permissao (tipo_nome, entidade_tipo) FROM stdin;
\.


--
-- TOC entry 4303 (class 0 OID 800041)
-- Dependencies: 438
-- Data for Name: documento_usuario; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento_usuario (id, usuario_id) FROM stdin;
\.


--
-- TOC entry 4304 (class 0 OID 800056)
-- Dependencies: 439
-- Data for Name: documento_veiculo; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento_veiculo (id, veiculo_placa) FROM stdin;
7	XXX4444
10	BBB11111
11	IBC2472
\.


--
-- TOC entry 4315 (class 0 OID 808150)
-- Dependencies: 450
-- Data for Name: documento_viagem; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.documento_viagem (id, viagem_id) FROM stdin;
\.


--
-- TOC entry 4321 (class 0 OID 816815)
-- Dependencies: 456
-- Data for Name: fluxo_pendencia; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.fluxo_pendencia (id, criado_em, entidade_tipo, entidade_id, status, analista, motivo) FROM stdin;
1	2025-11-24 10:50:09.885782	EMPRESA	03929471000177	AGUARDANDO_ANALISE	\N	\N
9	2025-12-08 14:56:53.161571	VEICULO	BBB11111	AGUARDANDO_ANALISE	\N	\N
23	2025-12-10 14:40:57.207103	VEICULO	BBB11111	EM_ANALISE	anal@anal	\N
24	2025-12-15 08:06:02.823267	EMPRESA	11111111111121	AGUARDANDO_ANALISE	\N	\N
25	2025-12-15 08:07:54.08465	EMPRESA	11111111113331	AGUARDANDO_ANALISE	\N	\N
26	2025-12-15 08:47:09.626316	EMPRESA	99999999999999999	AGUARDANDO_ANALISE	\N	\N
27	2025-12-15 08:56:14.144486	EMPRESA	888787878787887	AGUARDANDO_ANALISE	\N	\N
28	2025-12-15 11:44:42.294363	EMPRESA	47584754857	AGUARDANDO_ANALISE	\N	\N
29	2025-12-15 11:54:37.502643	EMPRESA	398293829382983	AGUARDANDO_ANALISE	\N	\N
30	2025-12-15 12:06:00.985419	EMPRESA	666666666666666	AGUARDANDO_ANALISE	\N	\N
31	2025-12-15 12:20:50.353761	EMPRESA	33333333333	AGUARDANDO_ANALISE	\N	\N
32	2025-12-15 12:27:21.656074	EMPRESA	444444444	AGUARDANDO_ANALISE	\N	\N
33	2025-12-15 12:32:20.905162	EMPRESA	55555555	AGUARDANDO_ANALISE	\N	\N
34	2025-12-15 12:47:32.606014	EMPRESA	666666666	AGUARDANDO_ANALISE	\N	\N
35	2025-12-15 14:00:45.841318	EMPRESA	77777777	AGUARDANDO_ANALISE	\N	\N
36	2025-12-16 09:02:51.437437	MOTORISTA	1	AGUARDANDO_ANALISE	\N	\N
37	2025-12-16 11:42:09.296079	EMPRESA	888888888	AGUARDANDO_ANALISE	\N	\N
38	2025-12-16 11:46:33.542624	EMPRESA	9999999999	AGUARDANDO_ANALISE	\N	\N
39	2025-12-16 11:49:15.941454	EMPRESA	10000000000000000	AGUARDANDO_ANALISE	\N	\N
40	2025-12-16 12:04:11.162598	EMPRESA	11111111111	AGUARDANDO_ANALISE	\N	\N
41	2025-12-16 12:06:39.246458	EMPRESA	121212121212	AGUARDANDO_ANALISE	\N	\N
42	2025-12-16 12:52:31.34317	EMPRESA	111111111111111	AGUARDANDO_ANALISE	\N	\N
43	2025-12-16 13:31:00.472385	EMPRESA	222222221211111112111	AGUARDANDO_ANALISE	\N	\N
44	2025-12-17 12:51:40.973861	EMPRESA	222222221211111112111	EM_ANALISE	anal@anal	\N
52	2026-01-06 11:39:06.06737	EMPRESA	111111111111111	EM_ANALISE	anal@anal	\N
56	2026-01-06 12:11:51.493939	EMPRESA	111111111111111	APROVADO	anal@anal	\N
57	2026-01-07 12:48:40.097817	EMPRESA	00865046000173	AGUARDANDO_ANALISE	\N	\N
58	2026-01-07 13:24:49.056205	EMPRESA	87788931000184	AGUARDANDO_ANALISE	\N	\N
59	2026-01-09 08:52:09.778803	EMPRESA	86464646464	AGUARDANDO_ANALISE	\N	\N
60	2026-01-09 08:56:00.565115	EMPRESA	88888898989888	AGUARDANDO_ANALISE	\N	\N
61	2026-01-09 12:09:42.604514	EMPRESA	222222221211111112111	APROVADO	anal@anal	\N
62	2026-01-09 12:10:04.87464	VEICULO	BBB11111	REJEITADO	anal@anal	nopnopn
63	2026-01-12 10:48:56.066904	EMPRESA	4545454545	AGUARDANDO_ANALISE	\N	\N
64	2026-01-12 12:36:48.265181	EMPRESA	4545454545	EM_ANALISE	anal@anal	\N
65	2026-01-12 12:38:05.473332	EMPRESA	88888898989888	EM_ANALISE	anal@anal	\N
66	2026-01-12 12:40:30.782647	EMPRESA	4545454545	REJEITADO	anal@anal	nao serviu
67	2026-01-12 12:42:08.633751	EMPRESA	88888898989888	APROVADO	anal@anal	\N
68	2026-01-12 12:42:42.338641	EMPRESA	4545454545	AGUARDANDO_ANALISE	\N	\N
69	2026-01-12 12:42:59.21312	EMPRESA	4545454545	EM_ANALISE	anal@anal	\N
\.


--
-- TOC entry 4307 (class 0 OID 800195)
-- Dependencies: 442
-- Data for Name: motorista; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.motorista (id, empresa_cnpj, cpf, cnh, email, nome, data_cadastro, eventual_status) FROM stdin;
1	03929471000177	111111	1111111	dggffjkfj@cjhcf	motoristinha	2025-11-05 18:35:24.690815	\N
2	3333333331313	12111111111	99999999999988889	joseh@lala	joseh	2026-03-02 13:47:12.48619	\N
\.


--
-- TOC entry 4314 (class 0 OID 808120)
-- Dependencies: 449
-- Data for Name: passageiro; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.passageiro (id, viagem_id, nome, cpf) FROM stdin;
\.


--
-- TOC entry 4318 (class 0 OID 816800)
-- Dependencies: 453
-- Data for Name: status_pendencia; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.status_pendencia (status, nome) FROM stdin;
AGUARDANDO_ANALISE	Aguardando Análise
EM_ANALISE	Em Análise
APROVADO	Aprovado
REJEITADO	Rejeitado
\.


--
-- TOC entry 4319 (class 0 OID 816807)
-- Dependencies: 454
-- Data for Name: tipo_entidade_pendencia; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.tipo_entidade_pendencia (tipo, descricao) FROM stdin;
EMPRESA	Empresa
VEICULO	Veículo
MOTORISTA	Motorista
\.


--
-- TOC entry 4312 (class 0 OID 808062)
-- Dependencies: 447
-- Data for Name: viagem; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.viagem (id, nome_contratante, cpf_cnpj_contratante, regiao_codigo, municipio_origem, municipio_destino, ida_em, volta_em, viagem_tipo, veiculo_placa, motorista_id, motorista_aux_id, descricao) FROM stdin;
\.


--
-- TOC entry 4310 (class 0 OID 808001)
-- Dependencies: 445
-- Data for Name: viagem_tipo; Type: TABLE DATA; Schema: eventual; Owner: -
--

COPY eventual.viagem_tipo (nome) FROM stdin;
Passeios Turísticos
Excursões
Eventos
Congressos
Shows
Festas
Encontros Religiosos
Encontros Esportivos
Outros
\.


--
-- TOC entry 4296 (class 0 OID 799650)
-- Dependencies: 431
-- Data for Name: papel; Type: TABLE DATA; Schema: web; Owner: -
--

COPY web.papel (nome) FROM stdin;
EMPRESA
USUARIO_EMPRESA
ANALISTA
\.


--
-- TOC entry 4317 (class 0 OID 816620)
-- Dependencies: 452
-- Data for Name: token_validacao_email; Type: TABLE DATA; Schema: web; Owner: -
--

COPY web.token_validacao_email (id, usuario_id, token, criado_em, expira_em) FROM stdin;
23	55	17IvFEv8zoKAXuHGzuzr6Ybbi51IsvVaHWDVWFoi6Fc	2025-12-16 15:04:11.183798	2025-12-17 15:04:11.183801
24	56	WHhwnfZbp_ElMFM4zS88l5K_wc1-xM7_Ddg3RIS83jk	2025-12-16 15:06:39.251439	2025-12-17 15:06:39.251442
30	64	MFqsq3oDjh_wOy2WGLuZPa5uashF7D75LWgCG6gx4u0	2026-01-09 11:52:09.815353	2026-01-10 11:52:09.815356
\.


--
-- TOC entry 4298 (class 0 OID 799667)
-- Dependencies: 433
-- Data for Name: usuario; Type: TABLE DATA; Schema: web; Owner: -
--

COPY web.usuario (id, papel_nome, email, nome, cpf, data_nascimento, telefone, senha, empresa_cnpj, criado_em, atualizado_em, ativo, email_validado) FROM stdin;
52	EMPRESA	marcelohz+oito@gmail.com	888888888888	\N	\N	\N	\N	888888888	2025-12-16 11:42:09.296079	2025-12-16 11:43:08.312228	t	t
60	EMPRESA	marcelohz+olha@gmail.com	OLHA, MANO	\N	\N	\N	scrypt:32768:8:1$fwuZdzJP0CQr1MCy$1a4582c546a9efd4793953a07600e31e8c41b67c682026bfc0fd320334bf1083e3e7e662e94189c50197a902af95fc830e784bb44260b6c6bfa1e1eadb770f4d	00865046000173	2026-01-07 13:03:04.950977	2026-01-07 13:03:30.481063	t	t
64	EMPRESA	skcjwij@iksjncfwic	76777	\N	\N	\N	\N	86464646464	2026-01-09 08:52:09.778803	2026-01-09 08:52:09.778803	t	f
1	EMPRESA	master@master	Master User	\N	\N	\N	scrypt:32768:8:1$vUTnyBOcclIzTdHJ$e4b7b578e2589c1cb45370f29087325862aab982966880e5c227132c8d95050c19aec10aa1975496f98bb072e1fdfda5aef534377a47636ea0fd3b6b32851cd7	03929471000177	2025-10-20 10:03:33.915375	2025-10-20 10:03:33.915375	t	t
3	EMPRESA	oi@oi	oioi	\N	\N	\N	scrypt:32768:8:1$U6zR2voA2GjhqaaV$f10a24823f57b098ddbc2b949a33c05c5476ce4f57b9d1e122238f2962249271d4b5933cf8b1e032ef0f1ed8d154bd59000e5862d3c08f7c79f94d92c671cbc9	123456	2025-10-24 10:39:53.851594	2025-10-24 10:39:53.851594	t	t
4	EMPRESA	dois@dois	razao 2	\N	\N	\N	scrypt:32768:8:1$BLZQrce2GnvQuDY2$fc927c18ce988e1531570179670b2495ad1348d69999bac62b5e12f09873006ea556a8a2cc96ffd27b7b62697380c828b78cb02410b8bc96db97678f8a935f50	222222222222222222	2025-10-28 08:56:20.623233	2025-10-28 08:56:20.623233	t	t
5	EMPRESA	tres@tres	raz 3	\N	\N	\N	scrypt:32768:8:1$HGGCkZufzypUhTHu$f5b594b580b9f676b36aef235224fd62fa5c99a6f43dc562651585b8ed3b33c016f3b94ac537f100596cc5be4f6fef1c03433c7b52467569bd7e127406840a0a	333333333	2025-10-28 10:07:55.869278	2025-10-28 10:07:55.869278	t	t
7	USUARIO_EMPRESA	lalalal@dlod	noooooome	1111111111	2002-02-02	11111	scrypt:32768:8:1$HCHfO5tCGXU0s405$81787e588a4f8f08b8f777efe0e209d1922a246f468c79aad248e8de6638badac81b335c5ee2c083d9618cfa9b42ff6d814e957fa6f0739d02d629fa9839aa91	\N	2025-10-29 10:52:17.430819	2025-10-29 10:52:17.430819	t	t
53	EMPRESA	marcelohz+nove@gmail.com	999999999	\N	\N	\N	\N	9999999999	2025-12-16 11:46:33.542624	2025-12-16 11:46:52.01485	t	t
61	EMPRESA	marcelohz+yeti@gmail.com	YETI	\N	\N	\N	scrypt:32768:8:1$lG2gpMRCs5nRBi2E$09956ed97e12818925cf8e9b138f535c918f5db11b52824a3fc261df94a12f88fbfb433e9e2393e08e50c13af725c42ee9a89943de551394e855fdcd69c17023	87788931000184	2026-01-07 13:24:49.056205	2026-01-07 13:25:06.041528	t	t
65	EMPRESA	lalala@clclwdlc.com	88888888898989	\N	\N	\N	\N	88888898989888	2026-01-09 08:56:00.565115	2026-01-09 08:56:12.176372	t	t
68	EMPRESA	net@net	net	\N	\N	\N	AQAAAAIAAYagAAAAEEAFwXnSqxkorD1NYBRAjNmzPwvRLDtJpMSIe/WW+p/zrnDefXZ6MUJuwKck3ylGwQ==	3333333331313	2026-03-02 13:07:06.525791	2026-03-02 13:07:06.525791	t	t
31	EMPRESA	newempresa@example.com	Empresa Nova S.A.	\N	\N	\N	scrypt:32768:8:1$jYzkzWwh5abWqMxJ$c824a83363254fbb530ecdbff399aef86f1d28a30472ab3530be49e74c6ac6ba451e4318edb102d6797cbd50edc68fbd1a225ea684f38385932229b221e74477	11111111000199	2025-11-18 12:07:17.433554	2025-11-18 12:07:17.433554	f	t
54	EMPRESA	marcelohz+dez@gmail.com	1000000000	\N	\N	\N	\N	10000000000000000	2025-12-16 11:49:15.941454	2025-12-16 11:49:29.971019	t	t
55	EMPRESA	marcelohz+onze@gmail.com	111111111111111111	\N	\N	\N	\N	11111111111	2025-12-16 12:04:11.162598	2025-12-16 12:04:11.162598	t	f
56	EMPRESA	marcelohz+doze@gmail.com	12121212	\N	\N	\N	\N	121212121212	2025-12-16 12:06:39.246458	2025-12-16 12:06:39.246458	t	f
57	EMPRESA	marcelohz+1@gmail.com	MAIS 1	\N	\N	\N	scrypt:32768:8:1$gSUOIm0juT5aRRXP$37e709add6101ddb702f93871392a31330a1c115c93ec8075cada242e25ace46fa454588925a5f2c9c9550c4615f44065a1b5c0a1db4765f4a92bdd062f34f9c	111111111111111	2025-12-16 12:52:31.34317	2025-12-16 12:55:28.073829	t	t
24	EMPRESA	pend@pend	pendentihno	\N	\N	\N	scrypt:32768:8:1$PFTWPZahd0m7LPP0$45594b400dab4ab516a929a4c69d4bf49697b16256ec122a00f08fa2fafb362baee7036c8438b5e77693a4f79f1e517c8829f6288ad024b54579d717c582d6f9	33333333333333	2025-11-06 10:33:28.747254	2025-11-06 10:33:28.747254	t	t
14	EMPRESA	doc@doc	documentos	\N	\N	\N	scrypt:32768:8:1$Xri5ilm6piR7Qzqr$7ec26332ceaeb41e6f7fed87598d5d05ee82b02528e88c2d3e6e251c9b8365bce0a48adb47263e826f3ce575493546daac55d553616265411c7550f481360c92	6565655665574	2025-10-31 13:18:43.167498	2025-10-31 13:18:43.167498	t	t
20	USUARIO_EMPRESA	johnny@atered	johnny altered	23489843943	2025-11-04		scrypt:32768:8:1$VzCMS6eclI5kKf8O$ad3aa504b22903e9d8ac5fc93f3b3ab4adcd2e8c38cad6ae6678995e17a30d2dce4415cd9f6fde152c4384aad997c30ee71ac66f299125507db5a5ba4deae17e	03929471000177	2025-11-04 09:54:54.133977	2025-11-10 08:09:41.920885	f	t
32	EMPRESA	empresaexistente@example.com	Empresa Existente SA	\N	\N	\N	scrypt:32768:8:1$eokrCa8EXoZDbvAO$fb1972e8799420b201f91028dcb5d269d215cdc7e100ea49d4e935bff54d5d031e8c075e76a199097d080950066ebfbd9f8a7119a37c85715dd0ce55f8ba3da5	22222222000133	2025-11-18 12:07:26.546968	2025-11-18 12:07:26.546968	f	t
19	USUARIO_EMPRESA	manuelito@bang	manuelito bangbang	12121121212	2002-02-02	554545454	scrypt:32768:8:1$yvt3f0bTucquMOio$db8e803567b1dc293d5311c1f000f1ffb8c7a32f9fe952b950b46a8314e8ae456376d97e49670b8a0f8091a7c825eec329ae43a300bcf934433dd940598bc292	03929471000177	2025-11-04 09:45:15.597911	2025-11-04 12:11:02.397674	f	t
15	USUARIO_EMPRESA	novo@novo	mais um user	9999999999	2002-02-02	515151515	scrypt:32768:8:1$a8gGq3cn1CGlHpr2$b4c49787a8cfe2be686d06103b965a17bb21dfd0da91bdc79f4a458448ebc1d49f070038f54e3e100c1e8897661e8905f13e6448a49ce671f27ddbaf29dbd97b	03929471000177	2025-11-03 07:48:56.371969	2025-11-04 12:12:06.371379	f	t
18	USUARIO_EMPRESA	tana@jura	tanajnura	656565	2002-02-02	51515	scrypt:32768:8:1$F4USvrEPyLUCqUQ7$a9763d5693d820c1a96a212e5d28bde426abaebe5257f17b440ecdcd0de9846126eb5b7ddc6296926f9370f1d59018874dbe823ad795a38b368fbd0fcb206781	03929471000177	2025-11-03 08:13:40.099598	2025-11-04 11:46:47.506465	f	t
17	USUARIO_EMPRESA	cigana@cigana	cigana	23982983	2002-01-01	151515	scrypt:32768:8:1$CdKUKo9SRRuj9gwU$4c0ab4b60bf59d6f7ee89bed776e3bf14bfd08624f14d763a51f5283eac8849078c4dd987de511055b2b7c2f6b48591c5d87bd63db9b5b1ce26cee9f24e7ac4c	03929471000177	2025-11-03 07:57:47.187123	2025-11-04 11:46:49.345364	f	t
22	USUARIO_EMPRESA	ebilero@wasoyijhg	ebilemaero	8988888	2002-02-02	323232323	scrypt:32768:8:1$TD6gQ99jUSfUYor6$9f71bfec2ec8081b0bcffa4e99738a349f034a0a880bc9bc52a6fc79ef39db2e59bc3cbea30356807f7f7d1827263e7685f8931051838b69b42249b1482018d4	03929471000177	2025-11-04 11:47:44.326372	2025-11-04 13:09:36.775099	f	t
21	USUARIO_EMPRESA	capencio@klala	capencio orioundo	23293829382	2002-02-02	787787	scrypt:32768:8:1$pGqjGboZSN4Rxh9F$eb1cfc73c6593f6534ed8d89ecf14f47f635f30661ab37e412c59577e73b9eb0d37ae8b186e08b1ada88e1caec4a97596b794edbdac232e02e6a8e751562adaf	03929471000177	2025-11-04 11:42:17.912711	2025-11-04 11:42:38.65908	t	t
23	ANALISTA	amanda	amanda gomez		2002-02-02		scrypt:32768:8:1$vUTnyBOcclIzTdHJ$e4b7b578e2589c1cb45370f29087325862aab982966880e5c227132c8d95050c19aec10aa1975496f98bb072e1fdfda5aef534377a47636ea0fd3b6b32851cd7	03929471000177	2025-11-04 13:12:56.322542	2025-11-04 13:12:56.322542	t	t
10	USUARIO_EMPRESA	bilu@bilu	bilu	2262626262	2002-11-11	99999999999	scrypt:32768:8:1$gy6adl2GL0bqvfRd$f8f8018c64c041e23018f01ea92cd3c4163f40a61a3a262a393bdfd3f9f25df8049b70b71f6b65cb7dc1f38c8ec7a3c8a72f6e46a83df53faaa29c78793ef75a	03929471000177	2025-10-29 12:51:24.966618	2025-11-04 11:47:57.450654	f	t
16	USUARIO_EMPRESA	nasceu@para	nasci pra sqn	6666666666	2222-01-01	11515115	scrypt:32768:8:1$PyHTMD7RRD95bZ3T$d5a3b4da866e1aa4d15ac25a00bb43fe25c4a26c769ced9703d83525494799c9e4605149bab8c5b57e962ca7558355aaeb843a728f25e1d276de47c7700de760	03929471000177	2025-11-03 07:57:15.707232	2025-11-04 13:12:16.236831	f	t
30	EMPRESA	nove@nove		\N	\N	\N	scrypt:32768:8:1$bM7QseII5H8IT2qZ$e326cefe8c4a9431ce0f1d7ed1b2fc1ad1ec757e3d2591d5ffda13fed13c3cb1e29283f050acae846b1fe015c123aef9a2b897e07d82747eba9a22218c15236e	99999999999999	2025-11-18 08:35:31.471573	2025-11-18 08:35:31.471573	t	t
33	EMPRESA	existinguser@example.com	Empresa Duplicada SA	\N	\N	\N	scrypt:32768:8:1$GXcBLKZivv3AgToe$0c36a93662aeeb8bf71f9f5edca25b4a306f6cdf57b2b74c1aaed56fcde9fe06508df961ddd2f75317d5a89d307cc19df4e8297507c2a99cf34be3963d131e31	33333333000155	2025-11-18 12:07:43.705577	2025-11-18 12:07:43.705577	f	t
34	EMPRESA	marcelohz@gmail.com	ESCUTE IRMAO	\N	\N	\N	scrypt:32768:8:1$ELEMEXd8EHFaWifx$0e436ba53c47b4ed4cc6eb858d8989be735f04553f3a8ebe80b79afce79c068a1308066a0d846a86e1bacf0d78b5de7acbe9debda6588a8edae892e71eee63b5	88	2025-11-18 12:31:47.784435	2025-11-18 12:39:37.882951	t	t
37	ANALISTA	anal@anal	anal	22222222223	2002-02-02	\N	scrypt:32768:8:1$vUTnyBOcclIzTdHJ$e4b7b578e2589c1cb45370f29087325862aab982966880e5c227132c8d95050c19aec10aa1975496f98bb072e1fdfda5aef534377a47636ea0fd3b6b32851cd7	\N	2025-11-17 14:00:55.295952	2025-11-17 14:00:55.295952	t	t
46	EMPRESA	marcelohz+dois@gmail.com	6666666666	\N	\N	\N	scrypt:32768:8:1$TqrcWMXYTRnbnyfk$7bd01588b29263d4294e69573d0dd7ce1f594051aee57dbbed0c627e6fa8248335f6a2ec68a097b95a027cc4a875ad71cdafd1297f9b547d8a49d906b87ff9cf	666666666666666	2025-12-15 12:06:00.985419	2025-12-15 12:06:52.3235	f	t
47	EMPRESA	marcelohz+tres@gmail.com	33333333333	\N	\N	\N	scrypt:32768:8:1$cteKSZgEe7g68itX$cc9dbf8c1520e472a6fc5163e5858b1d97e58b7757af4f80146153b0db5e3e8c0c532bb8e100027d1f28ae08dc82667a8627cb0ee06691f125426d0f88d57094	33333333333	2025-12-15 12:20:50.353761	2025-12-15 12:23:22.825406	f	t
48	EMPRESA	marcelohz+quatro@gmail.com	444444444444	\N	\N	\N	scrypt:32768:8:1$LjjOFWgGZHEJxAOW$ccc6fce1dd2145285f55e75959437f85cf2209b6eb143b841c8b06b58fe9cb125bf5918697da48b08f1286473f2bed4fc8abfa71e94109118744b399fc217013	444444444	2025-12-15 12:27:21.656074	2025-12-15 12:27:34.084319	t	t
49	EMPRESA	marcelohz+cinco@gmail.com	55555	\N	\N	\N	scrypt:32768:8:1$aoWt1etlyFZUT69o$e0c15964efc0e253f07ace0b05e80a0493fb389f852f930fe4491c3be065bd81f652101a2ad5defa426f5e5d28fae409e0b28f553c633d5fb45e6b60dae277a0	55555555	2025-12-15 12:32:20.905162	2025-12-15 12:32:20.905162	t	t
58	EMPRESA	marcelohz+2@gmail.com	MAAIS DOES	\N	\N	\N	scrypt:32768:8:1$jsF3GoTL5lG3Xw7n$537c72877af12d4a52096a359db24c3f5e6c1ac775c675ff6a5980f902a108c8513a011dc5da73d2938f4ea82b24759024170961d566edaf5cae080297f408ce	222222221211111112111	2025-12-16 13:31:00.472385	2025-12-16 13:31:27.228282	t	t
66	EMPRESA	lala@lala	TESTE	\N	\N	\N	scrypt:32768:8:1$j5ILc9Oz39TaMYiJ$8b70feda981a0f4ce1deca3a9d753f4c16309eb1a84e6429b3fa2900819883cd2f24cc2e504f6938b4ce50d584d9ff550a66be25db3bcd3b69211a793817739f	4545454545	2026-01-12 10:48:56.066904	2026-01-12 10:59:12.228464	t	t
38	EMPRESA	woo@woo	WOO HOOO	\N	\N	\N	scrypt:32768:8:1$XVz3fj6EKQa6z2ow$ab0e29e9043ad98bb3c514fc0753f60f8eb05d115a484a0ca0e86150e47fe049722d2dffc2fddc5bb8faa1492a7bdbc8d65ec699a66782f93c73280ad58d5e69	99999595959595	2025-11-24 09:54:16.488275	2025-11-24 09:54:16.488275	f	t
27	ANALISTA	anal2@anal2	anal	4466655555	2002-02-02	\N	scrypt:32768:8:1$vUTnyBOcclIzTdHJ$e4b7b578e2589c1cb45370f29087325862aab982966880e5c227132c8d95050c19aec10aa1975496f98bb072e1fdfda5aef534377a47636ea0fd3b6b32851cd7	\N	2025-11-17 14:00:55.295952	2025-11-17 14:00:55.295952	t	t
39	EMPRESA	wopkodowijeifeif.com	RTAZ	\N	\N	\N	scrypt:32768:8:1$VrWA3UIZSKdrXz7E$37063ac7be5047eb962eeb342d634e25c86e39c847e7eaf7b085144e26e6ca0b1661d9e7db7fbb3b54d13db7cdba7f549dc8c8cf7d512bcdf0acef4e695adeb8	11111111111121	2025-12-15 08:06:02.823267	2025-12-15 08:06:02.823267	f	t
40	EMPRESA	marcelohzeventualgmail.com	INQUISIDORES INC	\N	\N	\N	scrypt:32768:8:1$wSqos4TfcKIjlOsL$4e63c53223165f1a2baa04838e94443a59d0b619fec5f54eadb3c0d6fdaebf0d36ad476d6c4bf7aea082fa146e597e83f05739a731629a9091fecf8298a5ca3e	11111111113331	2025-12-15 08:07:54.08465	2025-12-15 08:36:45.320733	t	t
41	EMPRESA	marcelohzlalagmail.com	LALA	\N	\N	\N	scrypt:32768:8:1$chegh2PMoNE1BINe$486ac126789b9447100fa4c8e9648aac339248f7e08672c802a5b861043ff1f4797f79d9a938621b722f0109aa46a70384207c525d442f41e9e4d6a1c9f659a2	99999999999999999	2025-12-15 08:47:09.626316	2025-12-15 08:47:09.626316	f	t
42	EMPRESA	llllmdmmdmdmdm.com	POPOPO	\N	\N	\N	scrypt:32768:8:1$2LmqLeAsYGdOqEpa$b66b23f69f5121bda4763cfe1a9eeefab693ad558806556e2010872c81f3a9537a7be5aa32714b170897d2c2b998b1d43b2f970f9e0deefd1f98ddd33ea36144	888787878787887	2025-12-15 08:56:14.144486	2025-12-15 08:56:14.144486	f	t
43	EMPRESA	marcelohzoigmail.com	SLDKWOD	\N	\N	\N	scrypt:32768:8:1$wg6G3epFmDbyKp8h$61b024f3852ed1b6c9ea3924d056535cf22184dbfe329e19e11ab8d3b8f35d51958a89d6710c9a87a82585ce2449a368fe41b313aac60bdfc142ba624eb07881	47584754857	2025-12-15 11:44:42.294363	2025-12-15 11:44:42.294363	f	t
45	EMPRESA	marcelohz+oi@gmail.com	293829839283	\N	\N	\N	scrypt:32768:8:1$n95iN5PD4mGcMIEl$6cf0301aab490409a20a299b117ab1c4ead7988260fc5a0270a79500358f84c7ef74163a956105d587e84c2f4520b53a451e6c0118ac2390bf4367d51e0eb6c2	398293829382983	2025-12-15 11:54:37.502643	2025-12-15 12:00:04.489993	f	t
50	EMPRESA	marcelohz+seis@gmail.com	66666666666	\N	\N	\N	scrypt:32768:8:1$yOvgOrBwtN91OkYq$a3c7cbb9f2271a5c61d4e681bc7a5f51f7188a32e573ca58249e34a28ed047997b197e051cc721eaa0f859d1db17d2426e8e26325d8bc5cbab6124c91cd08106	666666666	2025-12-15 12:47:32.606014	2025-12-15 13:03:25.104823	t	t
51	EMPRESA	marcelohz+sete@gmail.com	777777	\N	\N	\N	scrypt:32768:8:1$7uZOptcCTcddd1dP$1e999954098536d887d2a422d928a161abc1373b0604143f519dade76c6619d4c4986feb387998b166b86fc42a37c93873eedddfbb44c4596e83084016d1541f	77777777	2025-12-15 14:00:45.841318	2025-12-15 15:07:02.154851	t	t
\.


--
-- TOC entry 4335 (class 0 OID 0)
-- Dependencies: 435
-- Name: documento_id_seq; Type: SEQUENCE SET; Schema: eventual; Owner: -
--

SELECT pg_catalog.setval('eventual.documento_id_seq', 26, true);


--
-- TOC entry 4336 (class 0 OID 0)
-- Dependencies: 443
-- Name: documento_motorista_id_seq; Type: SEQUENCE SET; Schema: eventual; Owner: -
--

SELECT pg_catalog.setval('eventual.documento_motorista_id_seq', 1, false);


--
-- TOC entry 4337 (class 0 OID 0)
-- Dependencies: 455
-- Name: fluxo_pendencia_id_seq; Type: SEQUENCE SET; Schema: eventual; Owner: -
--

SELECT pg_catalog.setval('eventual.fluxo_pendencia_id_seq', 69, true);


--
-- TOC entry 4338 (class 0 OID 0)
-- Dependencies: 441
-- Name: motorista_id_seq; Type: SEQUENCE SET; Schema: eventual; Owner: -
--

SELECT pg_catalog.setval('eventual.motorista_id_seq', 2, true);


--
-- TOC entry 4339 (class 0 OID 0)
-- Dependencies: 448
-- Name: passageiro_id_seq; Type: SEQUENCE SET; Schema: eventual; Owner: -
--

SELECT pg_catalog.setval('eventual.passageiro_id_seq', 1, false);


--
-- TOC entry 4340 (class 0 OID 0)
-- Dependencies: 446
-- Name: viagem_id_seq; Type: SEQUENCE SET; Schema: eventual; Owner: -
--

SELECT pg_catalog.setval('eventual.viagem_id_seq', 1, false);


--
-- TOC entry 4341 (class 0 OID 0)
-- Dependencies: 451
-- Name: token_validacao_email_id_seq; Type: SEQUENCE SET; Schema: web; Owner: -
--

SELECT pg_catalog.setval('web.token_validacao_email_id_seq', 32, true);


--
-- TOC entry 4342 (class 0 OID 0)
-- Dependencies: 432
-- Name: usuario_id_seq; Type: SEQUENCE SET; Schema: web; Owner: -
--

SELECT pg_catalog.setval('web.usuario_id_seq', 68, true);


--
-- TOC entry 4054 (class 2606 OID 800030)
-- Name: documento_empresa documento_empresa_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_empresa
    ADD CONSTRAINT documento_empresa_pkey PRIMARY KEY (id);


--
-- TOC entry 4064 (class 2606 OID 800215)
-- Name: documento_motorista documento_motorista_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_motorista
    ADD CONSTRAINT documento_motorista_pkey PRIMARY KEY (id);


--
-- TOC entry 4051 (class 2606 OID 800018)
-- Name: documento documento_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento
    ADD CONSTRAINT documento_pkey PRIMARY KEY (id);


--
-- TOC entry 4060 (class 2606 OID 800080)
-- Name: documento_tipo_permissao documento_tipo_permissao_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_tipo_permissao
    ADD CONSTRAINT documento_tipo_permissao_pkey PRIMARY KEY (tipo_nome, entidade_tipo);


--
-- TOC entry 4049 (class 2606 OID 800008)
-- Name: documento_tipo documento_tipo_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_tipo
    ADD CONSTRAINT documento_tipo_pkey PRIMARY KEY (nome);


--
-- TOC entry 4056 (class 2606 OID 800045)
-- Name: documento_usuario documento_usuario_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_usuario
    ADD CONSTRAINT documento_usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 4058 (class 2606 OID 800062)
-- Name: documento_veiculo documento_veiculo_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_veiculo
    ADD CONSTRAINT documento_veiculo_pkey PRIMARY KEY (id);


--
-- TOC entry 4074 (class 2606 OID 808154)
-- Name: documento_viagem documento_viagem_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_viagem
    ADD CONSTRAINT documento_viagem_pkey PRIMARY KEY (id);


--
-- TOC entry 4088 (class 2606 OID 816823)
-- Name: fluxo_pendencia fluxo_pendencia_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_pkey PRIMARY KEY (id);


--
-- TOC entry 4062 (class 2606 OID 800203)
-- Name: motorista motorista_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.motorista
    ADD CONSTRAINT motorista_pkey PRIMARY KEY (id);


--
-- TOC entry 4070 (class 2606 OID 808127)
-- Name: passageiro passageiro_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.passageiro
    ADD CONSTRAINT passageiro_pkey PRIMARY KEY (id);


--
-- TOC entry 4072 (class 2606 OID 808129)
-- Name: passageiro passageiro_unique_viagem_cpf; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.passageiro
    ADD CONSTRAINT passageiro_unique_viagem_cpf UNIQUE (viagem_id, cpf);


--
-- TOC entry 4082 (class 2606 OID 816806)
-- Name: status_pendencia status_pendencia_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.status_pendencia
    ADD CONSTRAINT status_pendencia_pkey PRIMARY KEY (status);


--
-- TOC entry 4084 (class 2606 OID 816813)
-- Name: tipo_entidade_pendencia tipo_entidade_pendencia_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.tipo_entidade_pendencia
    ADD CONSTRAINT tipo_entidade_pendencia_pkey PRIMARY KEY (tipo);


--
-- TOC entry 4068 (class 2606 OID 808069)
-- Name: viagem viagem_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_pkey PRIMARY KEY (id);


--
-- TOC entry 4066 (class 2606 OID 808007)
-- Name: viagem_tipo viagem_tipo_pkey; Type: CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem_tipo
    ADD CONSTRAINT viagem_tipo_pkey PRIMARY KEY (nome);


--
-- TOC entry 4039 (class 2606 OID 799656)
-- Name: papel papel_pkey; Type: CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.papel
    ADD CONSTRAINT papel_pkey PRIMARY KEY (nome);


--
-- TOC entry 4078 (class 2606 OID 816628)
-- Name: token_validacao_email token_validacao_email_pkey; Type: CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.token_validacao_email
    ADD CONSTRAINT token_validacao_email_pkey PRIMARY KEY (id);


--
-- TOC entry 4080 (class 2606 OID 816630)
-- Name: token_validacao_email token_validacao_email_token_key; Type: CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.token_validacao_email
    ADD CONSTRAINT token_validacao_email_token_key UNIQUE (token);


--
-- TOC entry 4043 (class 2606 OID 799680)
-- Name: usuario usuario_cpf_key; Type: CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_cpf_key UNIQUE (cpf);


--
-- TOC entry 4045 (class 2606 OID 799678)
-- Name: usuario usuario_email_key; Type: CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_email_key UNIQUE (email);


--
-- TOC entry 4047 (class 2606 OID 799676)
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- TOC entry 4052 (class 1259 OID 816934)
-- Name: documento_validade_idx; Type: INDEX; Schema: eventual; Owner: -
--

CREATE INDEX documento_validade_idx ON eventual.documento USING btree (validade);


--
-- TOC entry 4085 (class 1259 OID 816839)
-- Name: fluxo_pendencia_entidade_idx; Type: INDEX; Schema: eventual; Owner: -
--

CREATE INDEX fluxo_pendencia_entidade_idx ON eventual.fluxo_pendencia USING btree (entidade_tipo, entidade_id);


--
-- TOC entry 4086 (class 1259 OID 816840)
-- Name: fluxo_pendencia_latest_idx; Type: INDEX; Schema: eventual; Owner: -
--

CREATE INDEX fluxo_pendencia_latest_idx ON eventual.fluxo_pendencia USING btree (entidade_tipo, entidade_id, criado_em DESC);


--
-- TOC entry 4075 (class 1259 OID 816636)
-- Name: idx_token_validacao_email_token; Type: INDEX; Schema: web; Owner: -
--

CREATE INDEX idx_token_validacao_email_token ON web.token_validacao_email USING btree (token);


--
-- TOC entry 4076 (class 1259 OID 816637)
-- Name: idx_token_validacao_email_usuario; Type: INDEX; Schema: web; Owner: -
--

CREATE INDEX idx_token_validacao_email_usuario ON web.token_validacao_email USING btree (usuario_id);


--
-- TOC entry 4040 (class 1259 OID 799691)
-- Name: idx_usuario_email; Type: INDEX; Schema: web; Owner: -
--

CREATE INDEX idx_usuario_email ON web.usuario USING btree (email);


--
-- TOC entry 4041 (class 1259 OID 799692)
-- Name: idx_usuario_empresa_cnpj; Type: INDEX; Schema: web; Owner: -
--

CREATE INDEX idx_usuario_empresa_cnpj ON web.usuario USING btree (empresa_cnpj);


--
-- TOC entry 4118 (class 2620 OID 816846)
-- Name: fluxo_pendencia trg_analista_obrigatorio; Type: TRIGGER; Schema: eventual; Owner: -
--

CREATE TRIGGER trg_analista_obrigatorio BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_analista_obrigatorio();


--
-- TOC entry 4119 (class 2620 OID 816844)
-- Name: fluxo_pendencia trg_evitar_status_repetido; Type: TRIGGER; Schema: eventual; Owner: -
--

CREATE TRIGGER trg_evitar_status_repetido BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_evitar_status_repetido();


--
-- TOC entry 4120 (class 2620 OID 816936)
-- Name: fluxo_pendencia trg_motivo_obrigatorio; Type: TRIGGER; Schema: eventual; Owner: -
--

CREATE TRIGGER trg_motivo_obrigatorio BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_motivo_obrigatorio();


--
-- TOC entry 4121 (class 2620 OID 816842)
-- Name: fluxo_pendencia trg_valida_entidade; Type: TRIGGER; Schema: eventual; Owner: -
--

CREATE TRIGGER trg_valida_entidade BEFORE INSERT ON eventual.fluxo_pendencia FOR EACH ROW EXECUTE FUNCTION eventual.fn_valida_entidade();


--
-- TOC entry 4117 (class 2620 OID 816854)
-- Name: usuario trg_usuario_normalizar_email; Type: TRIGGER; Schema: web; Owner: -
--

CREATE TRIGGER trg_usuario_normalizar_email BEFORE INSERT OR UPDATE OF email ON web.usuario FOR EACH ROW EXECUTE FUNCTION web.normalizar_email_usuario();


--
-- TOC entry 4091 (class 2606 OID 800019)
-- Name: documento documento_documento_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento
    ADD CONSTRAINT documento_documento_tipo_nome_fkey FOREIGN KEY (documento_tipo_nome) REFERENCES eventual.documento_tipo(nome);


--
-- TOC entry 4093 (class 2606 OID 800036)
-- Name: documento_empresa documento_empresa_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_empresa
    ADD CONSTRAINT documento_empresa_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj);


--
-- TOC entry 4094 (class 2606 OID 800031)
-- Name: documento_empresa documento_empresa_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_empresa
    ADD CONSTRAINT documento_empresa_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- TOC entry 4092 (class 2606 OID 816929)
-- Name: documento documento_fluxo_pendencia_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento
    ADD CONSTRAINT documento_fluxo_pendencia_fkey FOREIGN KEY (fluxo_pendencia_id) REFERENCES eventual.fluxo_pendencia(id) ON DELETE SET NULL;


--
-- TOC entry 4101 (class 2606 OID 800216)
-- Name: documento_motorista documento_motorista_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_motorista
    ADD CONSTRAINT documento_motorista_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- TOC entry 4102 (class 2606 OID 800221)
-- Name: documento_motorista documento_motorista_motorista_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_motorista
    ADD CONSTRAINT documento_motorista_motorista_id_fkey FOREIGN KEY (motorista_id) REFERENCES eventual.motorista(id);


--
-- TOC entry 4099 (class 2606 OID 800081)
-- Name: documento_tipo_permissao documento_tipo_permissao_tipo_nome_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_tipo_permissao
    ADD CONSTRAINT documento_tipo_permissao_tipo_nome_fkey FOREIGN KEY (tipo_nome) REFERENCES eventual.documento_tipo(nome);


--
-- TOC entry 4095 (class 2606 OID 800046)
-- Name: documento_usuario documento_usuario_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_usuario
    ADD CONSTRAINT documento_usuario_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- TOC entry 4096 (class 2606 OID 800051)
-- Name: documento_usuario documento_usuario_usuario_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_usuario
    ADD CONSTRAINT documento_usuario_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES web.usuario(id);


--
-- TOC entry 4097 (class 2606 OID 800063)
-- Name: documento_veiculo documento_veiculo_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_veiculo
    ADD CONSTRAINT documento_veiculo_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- TOC entry 4098 (class 2606 OID 800068)
-- Name: documento_veiculo documento_veiculo_veiculo_placa_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_veiculo
    ADD CONSTRAINT documento_veiculo_veiculo_placa_fkey FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa);


--
-- TOC entry 4111 (class 2606 OID 808155)
-- Name: documento_viagem documento_viagem_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_viagem
    ADD CONSTRAINT documento_viagem_id_fkey FOREIGN KEY (id) REFERENCES eventual.documento(id) ON DELETE CASCADE;


--
-- TOC entry 4112 (class 2606 OID 808160)
-- Name: documento_viagem documento_viagem_viagem_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.documento_viagem
    ADD CONSTRAINT documento_viagem_viagem_id_fkey FOREIGN KEY (viagem_id) REFERENCES eventual.viagem(id);


--
-- TOC entry 4114 (class 2606 OID 816834)
-- Name: fluxo_pendencia fluxo_pendencia_analista_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_analista_fkey FOREIGN KEY (analista) REFERENCES web.usuario(email);


--
-- TOC entry 4115 (class 2606 OID 816824)
-- Name: fluxo_pendencia fluxo_pendencia_entidade_tipo_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_entidade_tipo_fkey FOREIGN KEY (entidade_tipo) REFERENCES eventual.tipo_entidade_pendencia(tipo);


--
-- TOC entry 4116 (class 2606 OID 816829)
-- Name: fluxo_pendencia fluxo_pendencia_status_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.fluxo_pendencia
    ADD CONSTRAINT fluxo_pendencia_status_fkey FOREIGN KEY (status) REFERENCES eventual.status_pendencia(status);


--
-- TOC entry 4100 (class 2606 OID 800204)
-- Name: motorista motorista_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.motorista
    ADD CONSTRAINT motorista_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj);


--
-- TOC entry 4110 (class 2606 OID 808130)
-- Name: passageiro passageiro_viagem_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.passageiro
    ADD CONSTRAINT passageiro_viagem_id_fkey FOREIGN KEY (viagem_id) REFERENCES eventual.viagem(id) ON DELETE CASCADE;


--
-- TOC entry 4103 (class 2606 OID 808100)
-- Name: viagem viagem_motorista_aux_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_motorista_aux_id_fkey FOREIGN KEY (motorista_aux_id) REFERENCES eventual.motorista(id);


--
-- TOC entry 4104 (class 2606 OID 808095)
-- Name: viagem viagem_motorista_id_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_motorista_id_fkey FOREIGN KEY (motorista_id) REFERENCES eventual.motorista(id);


--
-- TOC entry 4105 (class 2606 OID 808080)
-- Name: viagem viagem_municipio_destino_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_municipio_destino_fkey FOREIGN KEY (municipio_destino) REFERENCES geral.municipio(nome);


--
-- TOC entry 4106 (class 2606 OID 808075)
-- Name: viagem viagem_municipio_origem_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_municipio_origem_fkey FOREIGN KEY (municipio_origem) REFERENCES geral.municipio(nome);


--
-- TOC entry 4107 (class 2606 OID 808070)
-- Name: viagem viagem_regiao_codigo_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_regiao_codigo_fkey FOREIGN KEY (regiao_codigo) REFERENCES geral.regiao(codigo);


--
-- TOC entry 4108 (class 2606 OID 808090)
-- Name: viagem viagem_veiculo_placa_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_veiculo_placa_fkey FOREIGN KEY (veiculo_placa) REFERENCES geral.veiculo(placa);


--
-- TOC entry 4109 (class 2606 OID 808085)
-- Name: viagem viagem_viagem_tipo_fkey; Type: FK CONSTRAINT; Schema: eventual; Owner: -
--

ALTER TABLE ONLY eventual.viagem
    ADD CONSTRAINT viagem_viagem_tipo_fkey FOREIGN KEY (viagem_tipo) REFERENCES eventual.viagem_tipo(nome);


--
-- TOC entry 4113 (class 2606 OID 816631)
-- Name: token_validacao_email token_validacao_email_usuario_id_fkey; Type: FK CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.token_validacao_email
    ADD CONSTRAINT token_validacao_email_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES web.usuario(id) ON DELETE CASCADE;


--
-- TOC entry 4089 (class 2606 OID 799686)
-- Name: usuario usuario_empresa_cnpj_fkey; Type: FK CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_empresa_cnpj_fkey FOREIGN KEY (empresa_cnpj) REFERENCES geral.empresa(cnpj);


--
-- TOC entry 4090 (class 2606 OID 799681)
-- Name: usuario usuario_papel_nome_fkey; Type: FK CONSTRAINT; Schema: web; Owner: -
--

ALTER TABLE ONLY web.usuario
    ADD CONSTRAINT usuario_papel_nome_fkey FOREIGN KEY (papel_nome) REFERENCES web.papel(nome);


-- Completed on 2026-03-02 14:35:23

--
-- PostgreSQL database dump complete
--

