-- ============================================================
-- Archivo  : database/sql/ddl/01_schema.sql
-- Motor    : SQLite 3
-- Proyecto : Optimización SGBD Niantic — Pokémon GO
-- Caso     : Crisis de infraestructura julio 2016
-- Tablas   : 13 tablas, 9 reglas de negocio, 4 triggers, 1 vista
-- ============================================================

PRAGMA foreign_keys = ON;

-- ── 1. GENERACION ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS GENERACION (
    generacion_id       INTEGER PRIMARY KEY,
    numero              INTEGER NOT NULL,
    nombre              TEXT    NOT NULL,
    region              TEXT,
    anio_lanzamiento    INTEGER
);

-- ── 2. TIPO ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TIPO (
    tipo_id  INTEGER PRIMARY KEY,
    nombre   TEXT NOT NULL UNIQUE
);

-- ── 3. POKEMON ────────────────────────────────────────────────
-- RN-002: stat_total = suma de los 6 stats base
CREATE TABLE IF NOT EXISTS POKEMON (
    pokemon_id              INTEGER PRIMARY KEY,
    numero_nacional         INTEGER NOT NULL UNIQUE,
    nombre                  TEXT    NOT NULL,
    generacion_id           INTEGER NOT NULL REFERENCES GENERACION(generacion_id),
    hp_base                 INTEGER NOT NULL CHECK (hp_base > 0),
    ataque_base             INTEGER NOT NULL CHECK (ataque_base > 0),
    defensa_base            INTEGER NOT NULL CHECK (defensa_base > 0),
    ataque_especial_base    INTEGER NOT NULL CHECK (ataque_especial_base > 0),
    defensa_especial_base   INTEGER NOT NULL CHECK (defensa_especial_base > 0),
    velocidad_base          INTEGER NOT NULL CHECK (velocidad_base > 0),
    stat_total              INTEGER NOT NULL,
    es_legendario           INTEGER NOT NULL DEFAULT 0 CHECK (es_legendario IN (0,1)),
    es_mitico               INTEGER NOT NULL DEFAULT 0 CHECK (es_mitico IN (0,1)),
    tasa_captura            INTEGER,
    descripcion_categoria   TEXT,
    CONSTRAINT chk_stat_total CHECK (
        stat_total = hp_base + ataque_base + defensa_base +
                     ataque_especial_base + defensa_especial_base + velocidad_base
    )
);

-- ── 5. POKEMON_GO_STATS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS POKEMON_GO_STATS (
    pokemon_id   INTEGER PRIMARY KEY REFERENCES POKEMON(pokemon_id),
    max_cp       INTEGER,
    go_ataque    INTEGER,
    go_defensa   INTEGER,
    go_stamina   INTEGER
);

-- ── 6. POKEMON_TIPO ───────────────────────────────────────────
-- RN-001: máximo 2 tipos, slot 1 o 2
CREATE TABLE IF NOT EXISTS POKEMON_TIPO (
    pokemon_id  INTEGER NOT NULL REFERENCES POKEMON(pokemon_id),
    tipo_id     INTEGER NOT NULL REFERENCES TIPO(tipo_id),
    slot        INTEGER NOT NULL,
    PRIMARY KEY (pokemon_id, tipo_id),
    CONSTRAINT chk_slot CHECK (slot IN (1,2)),
    CONSTRAINT uq_pokemon_slot UNIQUE (pokemon_id, slot)
);

-- ── 7. EQUIPO ────────────────────────────────────────────────
-- Tres equipos fijos: Mystic, Valor, Instinct
-- Dato de referencia — solo 3 filas, no crece
CREATE TABLE IF NOT EXISTS EQUIPO (
    equipo_id   INTEGER PRIMARY KEY,
    nombre      TEXT NOT NULL UNIQUE,
    color       TEXT NOT NULL,
    lema        TEXT
);

-- ── 10. JUGADOR ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS JUGADOR (
    jugador_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_entrenador   TEXT    NOT NULL UNIQUE,
    email               TEXT    NOT NULL UNIQUE,
    pais                TEXT    NOT NULL DEFAULT 'CO',
    fecha_registro      TEXT    NOT NULL DEFAULT (DATE('now')),
    nivel               INTEGER NOT NULL DEFAULT 1 CHECK (nivel BETWEEN 1 AND 50),
    xp_total            INTEGER NOT NULL DEFAULT 0 CHECK (xp_total >= 0),
    es_menor_de_edad    INTEGER NOT NULL DEFAULT 0 CHECK (es_menor_de_edad IN (0,1)),
    equipo_id           INTEGER REFERENCES EQUIPO(equipo_id)
);

-- ── 11. SESION ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS SESION (
    sesion_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    jugador_id          INTEGER NOT NULL REFERENCES JUGADOR(jugador_id),
    inicio              TEXT    NOT NULL,
    fin                 TEXT,
    latitud             REAL,
    longitud            REAL,
    ciudad              TEXT,
    pais_sesion         TEXT,
    duracion_minutos    INTEGER CHECK (duracion_minutos IS NULL OR duracion_minutos > 0)
);

-- ── 12. CAPTURA ───────────────────────────────────────────────
-- RN-003: IVs entre 0 y 15
-- RN-005: fecha_captura >= fecha_registro del jugador (trigger)
CREATE TABLE IF NOT EXISTS CAPTURA (
    captura_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    jugador_id    INTEGER NOT NULL REFERENCES JUGADOR(jugador_id),
    pokemon_id    INTEGER NOT NULL REFERENCES POKEMON(pokemon_id),
    fecha_captura TEXT    NOT NULL DEFAULT (DATETIME('now')),
    cp_capturado  INTEGER NOT NULL CHECK (cp_capturado > 0),
    iv_ataque     INTEGER NOT NULL CHECK (iv_ataque  BETWEEN 0 AND 15),
    iv_defensa    INTEGER NOT NULL CHECK (iv_defensa BETWEEN 0 AND 15),
    iv_stamina    INTEGER NOT NULL CHECK (iv_stamina BETWEEN 0 AND 15),
    latitud       REAL,
    longitud      REAL
);

-- ── 13. POKEPARADA ────────────────────────────────────────────
-- Puntos de interés físicos donde los jugadores giran para obtener ítems.
-- Datos reales de Bogotá: landmarks registrados en la app de Pokémon GO.
-- Esta tabla es la fuente principal del tráfico masivo (80% de requests).
-- La crisis de 2016 fue causada en gran parte por spins simultáneos.
CREATE TABLE IF NOT EXISTS POKEPARADA (
    pokeparada_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT    NOT NULL,
    latitud         REAL    NOT NULL,
    longitud        REAL    NOT NULL,
    barrio          TEXT,
    ciudad          TEXT    NOT NULL DEFAULT 'Bogotá',
    pais            TEXT    NOT NULL DEFAULT 'CO',
    activa          INTEGER NOT NULL DEFAULT 1 CHECK (activa IN (0,1))
);

-- ── 14. GIMNASIO ──────────────────────────────────────────────
-- Ubicaciones físicas donde ocurren las batallas PvP y los Raids.
-- El equipo que controla el gimnasio defiende con sus Pokémon.
CREATE TABLE IF NOT EXISTS GIMNASIO (
    gimnasio_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT    NOT NULL,
    latitud         REAL    NOT NULL,
    longitud        REAL    NOT NULL,
    barrio          TEXT,
    ciudad          TEXT    NOT NULL DEFAULT 'Bogotá',
    pais            TEXT    NOT NULL DEFAULT 'CO',
    equipo_control  INTEGER REFERENCES EQUIPO(equipo_id),
    prestigio       INTEGER NOT NULL DEFAULT 0 CHECK (prestigio >= 0),
    activo          INTEGER NOT NULL DEFAULT 1 CHECK (activo IN (0,1))
);

-- ── 15. REGISTRO_BATALLA ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS REGISTRO_BATALLA (
    batalla_id              INTEGER PRIMARY KEY AUTOINCREMENT,
    jugador_atacante_id     INTEGER NOT NULL REFERENCES JUGADOR(jugador_id),
    jugador_defensor_id     INTEGER NOT NULL REFERENCES JUGADOR(jugador_id),
    pokemon_atacante_id     INTEGER NOT NULL REFERENCES POKEMON(pokemon_id),
    pokemon_defensor_id     INTEGER NOT NULL REFERENCES POKEMON(pokemon_id),
    gimnasio_id             INTEGER REFERENCES GIMNASIO(gimnasio_id),
    fecha                   TEXT    NOT NULL DEFAULT (DATETIME('now')),
    dano_infligido          INTEGER NOT NULL CHECK (dano_infligido >= 0),
    es_victoria_atacante    INTEGER NOT NULL CHECK (es_victoria_atacante IN (0,1))
);

-- ── 16. VISITA_POKEPARADA ─────────────────────────────────────
-- Tabla de alto volumen: cada spin de una Poképarada genera 1 fila.
-- A 45M DAU con 10+ spins/hora = 450M eventos/hora en el pico de 2016.
-- Sin índice en esta tabla → SCAN TABLE en cada apertura de app → colapso.
-- RN-013: cooldown de 5 min por parada (implementado en trigger)
CREATE TABLE IF NOT EXISTS VISITA_POKEPARADA (
    visita_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    jugador_id       INTEGER NOT NULL REFERENCES JUGADOR(jugador_id),
    pokeparada_id    INTEGER NOT NULL REFERENCES POKEPARADA(pokeparada_id),
    timestamp_visita TEXT    NOT NULL DEFAULT (DATETIME('now')),
    items_obtenidos  INTEGER NOT NULL DEFAULT 0 CHECK (items_obtenidos >= 0)
);

-- ── TRIGGERS ──────────────────────────────────────────────────

-- RN-005: captura no puede ser anterior al registro del jugador
CREATE TRIGGER IF NOT EXISTS trg_captura_fecha_valida
BEFORE INSERT ON CAPTURA
BEGIN
    SELECT CASE
        WHEN NEW.fecha_captura < (
            SELECT fecha_registro FROM JUGADOR WHERE jugador_id = NEW.jugador_id
        )
        THEN RAISE(ABORT, 'RN-005: fecha_captura no puede ser anterior al registro del jugador')
    END;
END;

-- RN-007: CP capturado no puede exceder MaxCP del Pokemon en GO
CREATE TRIGGER IF NOT EXISTS trg_captura_cp_valido
BEFORE INSERT ON CAPTURA
BEGIN
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM POKEMON_GO_STATS
            WHERE pokemon_id = NEW.pokemon_id
              AND NEW.cp_capturado > max_cp
        )
        THEN RAISE(ABORT, 'RN-007: cp_capturado excede el MaxCP del Pokemon en Pokemon GO')
    END;
END;

-- RN-011 / RN-012: Validaciones de batalla (equivalente a stored procedure)
-- Ver database/sql/ddl/06_stored_procedure.sql para el trigger completo
CREATE TRIGGER IF NOT EXISTS trg_batalla_validar_participantes
BEFORE INSERT ON REGISTRO_BATALLA
BEGIN
    SELECT CASE
        WHEN NEW.jugador_atacante_id = NEW.jugador_defensor_id
        THEN RAISE(ABORT, 'RN-011: El atacante y el defensor deben ser jugadores distintos')
    END;
    SELECT CASE
        WHEN NEW.dano_infligido < 0
        THEN RAISE(ABORT, 'RN-012: El dano_infligido no puede ser negativo')
    END;
END;

-- RN-013: Un jugador no puede girar la misma Poképarada más de 1 vez cada 5 minutos.
-- Esta regla modela el cooldown real de Pokémon GO y previene spam de requests.
-- En producción (Cloud Spanner): validación en capa de aplicación + rate limiting en GCLB.
CREATE TRIGGER IF NOT EXISTS trg_visita_pokeparada_cooldown
BEFORE INSERT ON VISITA_POKEPARADA
BEGIN
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM VISITA_POKEPARADA
            WHERE jugador_id    = NEW.jugador_id
              AND pokeparada_id = NEW.pokeparada_id
              AND timestamp_visita > DATETIME(NEW.timestamp_visita, '-5 minutes')
        )
        THEN RAISE(ABORT, 'RN-013: cooldown activo — espera 5 minutos antes de girar esta Poképarada de nuevo')
    END;
END;

-- ── VISTAS ───────────────────────────────────────────────────

-- Vista principal de análisis: Pokemon completo con tipos y generación
CREATE VIEW IF NOT EXISTS v_pokemon_completo AS
SELECT
    p.pokemon_id,
    p.numero_nacional,
    p.nombre,
    g.nombre          AS generacion,
    g.anio_lanzamiento,
    GROUP_CONCAT(t.nombre, ' / ') AS tipos,
    p.hp_base,
    p.ataque_base,
    p.defensa_base,
    p.ataque_especial_base,
    p.defensa_especial_base,
    p.velocidad_base,
    p.stat_total,
    p.es_legendario,
    p.es_mitico,
    gs.max_cp,
    gs.go_ataque,
    gs.go_defensa,
    gs.go_stamina
FROM POKEMON p
JOIN GENERACION g ON p.generacion_id = g.generacion_id
LEFT JOIN POKEMON_TIPO pt ON p.pokemon_id = pt.pokemon_id
LEFT JOIN TIPO t ON pt.tipo_id = t.tipo_id
LEFT JOIN POKEMON_GO_STATS gs ON p.pokemon_id = gs.pokemon_id
GROUP BY p.pokemon_id;

