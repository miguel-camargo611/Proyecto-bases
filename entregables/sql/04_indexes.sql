-- ============================================================
-- Archivo  : database/sql/ddl/04_indexes.sql
-- Motor    : SQLite 3
-- Propósito: Optimización de rendimiento — índices B-tree sobre
--            las columnas de mayor frecuencia de consulta.
--
-- ARGUMENTO DE OPTIMIZACIÓN:
--   Sin índices → cada query hace SCAN TABLE (O(n)).
--   Con índices → SQLite usa B-tree (O(log n)).
--   A 50M registros (escala real de Niantic), la diferencia es
--   la que separa un sistema funcional de uno que colapsa.
--
-- Ejecutar DESPUÉS de 01_schema.sql y de cargar los datos.
-- ============================================================

-- ── CAPTURA ──────────────────────────────────────────────────

-- Filtro más frecuente en la app: "mostrar mis capturas recientes"
-- Sin este índice: full scan de millones de filas por jugador
CREATE INDEX IF NOT EXISTS idx_captura_jugador_fecha
    ON CAPTURA(jugador_id, fecha_captura);

-- Análisis de popularidad: "¿cuál es el Pokémon más capturado?"
CREATE INDEX IF NOT EXISTS idx_captura_pokemon
    ON CAPTURA(pokemon_id);

-- ── SESION ───────────────────────────────────────────────────

-- Historial de sesiones por entrenador: pantalla "mis actividades"
CREATE INDEX IF NOT EXISTS idx_sesion_jugador
    ON SESION(jugador_id);

-- Filtros por rango de fechas: análisis de actividad diaria/semanal
CREATE INDEX IF NOT EXISTS idx_sesion_inicio
    ON SESION(inicio);

-- ── REGISTRO_BATALLA ─────────────────────────────────────────

-- Ranking histórico de batallas y cronología de eventos PvP
CREATE INDEX IF NOT EXISTS idx_batalla_fecha
    ON REGISTRO_BATALLA(fecha);

-- Victorias por jugador: "¿cuántas batallas gané esta semana?"
-- Índice compuesto: evita lookup adicional en es_victoria_atacante
CREATE INDEX IF NOT EXISTS idx_batalla_atacante_victoria
    ON REGISTRO_BATALLA(jugador_atacante_id, es_victoria_atacante);

-- ── POKEMON ──────────────────────────────────────────────────

-- Filtro de generación: usado por la vista v_pokemon_completo
-- y por cualquier query que agrupe Pokémon por generación
CREATE INDEX IF NOT EXISTS idx_pokemon_generacion
    ON POKEMON(generacion_id);

-- Ranking de poder: "top Pokémon más fuertes" — consulta frecuente
CREATE INDEX IF NOT EXISTS idx_pokemon_stat_total
    ON POKEMON(stat_total DESC);

-- ── POKEMON_GO_STATS ─────────────────────────────────────────

-- Validación del trigger trg_captura_cp_valido (RN-007):
-- cada inserción en CAPTURA consulta esta tabla — debe ser rápido
CREATE INDEX IF NOT EXISTS idx_go_stats_maxcp
    ON POKEMON_GO_STATS(max_cp DESC);


-- ============================================================
-- DEMOSTRACIÓN DE OPTIMIZACIÓN — EXPLAIN QUERY PLAN
-- Ejecutar cada bloque por separado para ver la diferencia.
-- ============================================================

-- ANTES del índice compuesto idx_captura_jugador_fecha:
-- (Descomentar para ver — requiere DROP INDEX previo en prueba limpia)
-- EXPLAIN QUERY PLAN
-- SELECT * FROM CAPTURA
-- WHERE jugador_id = 5 AND fecha_captura > '2023-01-01';
-- → SCAN TABLE CAPTURA  (examina TODAS las filas)

-- DESPUÉS del índice (estado actual tras ejecutar este archivo):
EXPLAIN QUERY PLAN
SELECT * FROM CAPTURA
WHERE jugador_id = 5 AND fecha_captura > '2023-01-01';
-- → SEARCH TABLE CAPTURA USING INDEX idx_captura_jugador_fecha

-- Índice de battles:
EXPLAIN QUERY PLAN
SELECT jugador_atacante_id, COUNT(*) AS victorias
FROM REGISTRO_BATALLA
WHERE jugador_atacante_id = 10 AND es_victoria_atacante = 1;
-- → SEARCH TABLE REGISTRO_BATALLA USING INDEX idx_batalla_atacante_victoria


-- ── VISITA_POKEPARADA ─────────────────────────────────────────
-- ARGUMENTO CENTRAL DEL PROYECTO:
-- En la crisis de julio 2016, 45M usuarios activos giraban Poképaradas
-- simultáneamente → cada apertura de app generaba 1+ queries a esta tabla.
-- Sin índice: SCAN TABLE en 50M registros/hora → colapso total.
-- Con índice B-tree: O(log n) — el sistema escala sin importar el volumen.

-- Historial de visitas por jugador: "¿cuándo giré esta parada por última vez?"
-- También valida el cooldown de RN-013 en el trigger trg_visita_pokeparada_cooldown
CREATE INDEX IF NOT EXISTS idx_visita_pokeparada_jugador_ts
    ON VISITA_POKEPARADA(jugador_id, timestamp_visita DESC);

-- Actividad por Poképarada: "¿cuál es la parada más visitada en Bogotá?"
CREATE INDEX IF NOT EXISTS idx_visita_pokeparada_parada_ts
    ON VISITA_POKEPARADA(pokeparada_id, timestamp_visita DESC);

-- Demo de optimización para VISITA_POKEPARADA:
EXPLAIN QUERY PLAN
SELECT * FROM VISITA_POKEPARADA
WHERE jugador_id = 1
ORDER BY timestamp_visita DESC
LIMIT 10;
-- → SEARCH TABLE VISITA_POKEPARADA USING INDEX idx_visita_pokeparada_jugador_ts
