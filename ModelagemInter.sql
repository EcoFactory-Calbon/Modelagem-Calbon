-- ========================================
-- RESET DO SCHEMA
-- ========================================

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

-- ========================================
-- CONFIGURAÇÃO PARA O INDEX
-- ========================================

create extension if not exists pg_trgm;

-- ========================================
-- TABELAS
-- ========================================

-- Admin
CREATE TABLE admin (
    email VARCHAR(255) PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    senha VARCHAR(255) NOT NULL
);

-- Log
CREATE TABLE log (
    id SERIAL PRIMARY KEY,
    operacao TEXT NOT NULL,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DAU
CREATE TABLE dau (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Localização
CREATE TABLE localizacao (
    id SERIAL PRIMARY KEY,
    estado VARCHAR(100) NOT NULL,
    cidade VARCHAR(100) NOT NULL
);

-- Categoria empresa
CREATE TABLE categoria_empresa(
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    descricao TEXT
);

CREATE TABLE empresa (
    id SERIAL PRIMARY KEY,
    cnpj CHAR(14) UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    id_localizacao INT NOT NULL,
    id_categoria INT NOT NULL,
    senha VARCHAR(255),
    FOREIGN KEY (id_localizacao) REFERENCES localizacao(id),
    FOREIGN KEY (id_categoria) REFERENCES categoria_empresa(id)
);

-- Setor
CREATE TABLE setor (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    id_empresa INT NOT NULL,
    FOREIGN KEY (id_empresa) REFERENCES empresa(id)
);

-- Cargo
CREATE TABLE cargo (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    id_setor INT NOT NULL,
    nivel_cargo TEXT NOT NULL,
    FOREIGN KEY (id_setor) REFERENCES setor(id)
);

-- Funcionário
CREATE TABLE funcionario (
    nome VARCHAR(255) NOT NULL,
    sobrenome VARCHAR(255),
    email VARCHAR(255) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL,
    numero_cracha BIGINT NOT NULL PRIMARY KEY,
    id_cargo INT NOT NULL,
    id_localizacao INT NOT NULL,
    is_gestor BOOLEAN DEFAULT FALSE,
    primeiro_acesso BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (id_cargo) REFERENCES cargo(id),
    FOREIGN KEY (id_localizacao) REFERENCES localizacao(id)
);

-- ========================================
-- FUNÇÕES E PROCEDURES
-- ========================================

-- Function: listar funcionários por empresa pelo id
CREATE OR REPLACE FUNCTION fn_listar_funcionarios_empresa(p_id_empresa INT)
RETURNS TABLE (
    numero_cracha BIGINT,
    nome VARCHAR,
    sobrenome VARCHAR,
    email VARCHAR,
    cargo VARCHAR,
    setor VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT f.numero_cracha,
           f.nome,
           f.sobrenome,
           f.email,
           c.nome AS cargo,
           s.nome AS setor
    FROM funcionario f
    JOIN cargo c ON f.id_cargo = c.id
    JOIN setor s ON c.id_setor = s.id
    WHERE s.id_empresa = p_id_empresa;
END;
$$ LANGUAGE plpgsql;

-- Function: listar funcionários por empresa pelo cnpj
CREATE OR REPLACE FUNCTION fn_listar_funcionarios_empresa_cnpj(p_cnpj text)
RETURNS TABLE (
    numero_cracha BIGINT,
    nome VARCHAR,
    sobrenome VARCHAR,
    email VARCHAR,
    cargo VARCHAR,
    setor VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT f.numero_cracha,
           f.nome,
           f.sobrenome,
           f.email,
           c.nome AS cargo,
           s.nome AS setor
    FROM funcionario f
    JOIN cargo c ON f.id_cargo = c.id
    JOIN setor s ON c.id_setor = s.id
    JOIN empresa e ON s.id_empresa = e.id
    WHERE e.cnpj = p_cnpj;
END;
$$ LANGUAGE plpgsql;

-- Funcion: Listar funcionário por empresa com o cnpj para com os ids
CREATE OR REPLACE FUNCTION fn_listar_funcionarios_empresa_cnpj_c(p_cnpj text)
RETURNS TABLE (
    numero_cracha BIGINT,
    nome VARCHAR,
    sobrenome VARCHAR,
    email VARCHAR,
    cargo VARCHAR,
    is_gestor BOOLEAN,
    id_localizacao INT,
    id_cargo INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT f.numero_cracha,
           f.nome,
           f.sobrenome,
           f.email,
           c.nome AS cargo,
           f.is_gestor,
           l.id,
           c.id
    FROM funcionario f
    JOIN cargo c ON f.id_cargo = c.id
    JOIN setor s ON c.id_setor = s.id
    JOIN empresa e ON s.id_empresa = e.id
    JOIN localizacao l on e.id_localizacao = l.id
    WHERE e.cnpj = p_cnpj;
END;
$$ LANGUAGE plpgsql;

-- Function: listar gestores por empresa
CREATE OR REPLACE FUNCTION fn_listar_gestores_empresa(p_id_empresa INT)
RETURNS TABLE (
    numero_cracha BIGINT,
    nome VARCHAR,
    sobrenome VARCHAR,
    email VARCHAR,
    cargo VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT f.numero_cracha,
           f.nome,
           f.sobrenome,
           f.email,
           c.nome AS cargo
    FROM funcionario f
    JOIN cargo c ON f.id_cargo = c.id
    JOIN setor s ON c.id_setor = s.id
    WHERE s.id_empresa = p_id_empresa AND f.is_gestor = TRUE;
END;
$$ LANGUAGE plpgsql;

-- Procedure: inserir funcionário
CREATE OR REPLACE PROCEDURE sp_inserir_funcionario(
    p_nome VARCHAR,
    p_sobrenome VARCHAR,
    p_email VARCHAR,
    p_senha VARCHAR,
    p_numero_cracha BIGINT,
    p_id_cargo INT,
    p_id_localizacao INT,
    p_is_gestor BOOLEAN DEFAULT FALSE,
    p_is_primeiro_acesso BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO funcionario (
        nome,
        sobrenome,
        email,
        senha,
        numero_cracha,
        id_cargo,
        id_localizacao,
        is_gestor,
        primeiro_acesso
    )
    VALUES (
        p_nome,
        p_sobrenome,
        p_email,
        p_senha,
        p_numero_cracha,
        p_id_cargo,
        p_id_localizacao,
        p_is_gestor,
        p_is_primeiro_acesso
    );
END;
$$;

-- Procedure: atualizar cargo de funcionário
CREATE OR REPLACE PROCEDURE sp_atualizar_cargo_funcionario(
    p_numero_cracha BIGINT,
    p_novo_id_cargo INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE funcionario
    SET id_cargo = p_novo_id_cargo
    WHERE numero_cracha = p_numero_cracha;
END;
$$;

-- ========================================
-- FUNÇÃO DE LOG
-- ========================================

CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'log' THEN
        RETURN NULL;
    END IF;

    INSERT INTO log (operacao)
    VALUES (TG_OP || ' em ' || TG_TABLE_NAME);

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- TRIGGERS DE LOG
-- ========================================

CREATE TRIGGER trg_log_admin
AFTER INSERT OR UPDATE OR DELETE ON admin
FOR EACH STATEMENT EXECUTE FUNCTION log_admin_action();

CREATE TRIGGER trg_log_empresa
AFTER INSERT OR UPDATE OR DELETE ON empresa
FOR EACH STATEMENT EXECUTE FUNCTION log_admin_action();

CREATE TRIGGER trg_log_funcionario
AFTER INSERT OR UPDATE OR DELETE ON funcionario
FOR EACH STATEMENT EXECUTE FUNCTION log_admin_action();

CREATE TRIGGER trg_log_setor
AFTER INSERT OR UPDATE OR DELETE ON setor
FOR EACH STATEMENT EXECUTE FUNCTION log_admin_action();

CREATE TRIGGER trg_log_cargo
AFTER INSERT OR UPDATE OR DELETE ON cargo
FOR EACH STATEMENT EXECUTE FUNCTION log_admin_action();

-- ========================================
-- INDEX
-- ========================================

CREATE INDEX idx_funcionario_cargo ON funcionario(id_cargo);
CREATE INDEX idx_funcionario_localizacao ON funcionario(id_localizacao);
CREATE INDEX idx_funcionario_isgestor ON funcionario(is_gestor);
CREATE INDEX idx_empresa_categoria ON empresa(id_categoria);
CREATE INDEX idx_empresa_localizacao ON empresa(id_localizacao);
CREATE INDEX idx_empresa_nome on empresa using gin (nome gin_trgm_ops);
CREATE INDEX idx_localizacao_estado ON localizacao using gin (estado gin_trgm_ops);
CREATE INDEX idx_localizacao_cidade on localizacao using gin (cidade gin_trgm_ops);
CREATE INDEX idx_setor_empresa ON setor(id_empresa);
CREATE INDEX idx_funcionario_cargo ON funcionario(id_cargo);
CREATE INDEX idx_funcionario_localizacao ON funcionario(id_localizacao);
CREATE INDEX idx_funcionario_isgestor ON funcionario(is_gestor);

select * from admin;

select * from cargo;

select * from categoria_empresa;

select * from dau;

select * from empresa;

select * from funcionario;

select * from localizacao;

select * from log;

select * from setor;