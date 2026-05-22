-- ============================================================
-- Archivo  : database/sql/queries/consultas_ventanas.sql
-- Motor    : SQLite 3
-- Propósito: Consultas con funciones de ventana (Window Functions).
--            Rúbrica: "funciones de ventana" — Fase 3, SQL 15 pts
-- Nota     : SQLite soporta Window Functions desde la versión 3.25
--            (septiembre 2018). Verificar con: SELECT sqlite_version()
-- ============================================================

-- ── Q-03: RANK() — Ranking de Pokémon por max_cp dentro de su tipo ──
--
-- Objetivo de negocio:
--   Niantic necesita saber cuáles son los Pokémon más poderosos
--   dentro de cada tipo para diseñar torneos y raids equilibrados.
--   Un ranking global no es útil — un Pokémon de tipo Agua compite
--   con otros de agua, no con Dragones. PARTITION BY resuelve esto.

SELECT
    p.nombre                                    AS pokemon,
    t.nombre                                    AS tipo_primario,
    gs.max_cp,
    gs.go_ataque,
    gs.go_defensa,
    gs.go_stamina,
    RANK() OVER (
        PARTITION BY t.tipo_id
        ORDER BY gs.max_cp DESC
    )                                           AS rank_en_tipo,
    COUNT(*) OVER (
        PARTITION BY t.tipo_id
    )                                           AS total_en_tipo
FROM POKEMON p
JOIN POKEMON_TIPO pt
    ON p.pokemon_id = pt.pokemon_id AND pt.slot = 1   -- tipo primario
JOIN TIPO t
    ON pt.tipo_id = t.tipo_id
JOIN POKEMON_GO_STATS gs
    ON p.pokemon_id = gs.pokemon_id
ORDER BY t.nombre ASC, rank_en_tipo ASC;

-- Interpretación esperada del resultado:
--   El tipo Dragón tiene el max_cp promedio más alto, seguido por
--   Psíquico y Lucha. Los top-1 de cada tipo son los Pokémon
--   "meta" de cada raid — Mewtwo lidera Psíquico, Dragonite/Rayquaza
--   lideran Dragón. Decisión: estos son los Pokémon cuya aparición
--   en eventos premium genera el mayor engagement de jugadores.


-- ── Q-04: AVG de ventana — stat_total vs. promedio de la generación ──
--
-- Objetivo de negocio:
--   ¿Cómo evolucionó el poder de los Pokémon a lo largo de las
--   generaciones? Este análisis detecta si hay "power creep"
--   (gens más recientes son sistemáticamente más fuertes) —
--   un factor de riesgo para la retención de jugadores de largo plazo.

SELECT
    g.nombre                                    AS generacion,
    g.numero                                    AS num_gen,
    p.nombre                                    AS pokemon,
    p.stat_total,
    ROUND(
        AVG(p.stat_total) OVER (
            PARTITION BY p.generacion_id
        )
    , 1)                                        AS promedio_generacion,
    ROUND(
        p.stat_total - AVG(p.stat_total) OVER (
            PARTITION BY p.generacion_id
        )
    , 1)                                        AS desviacion_vs_promedio,
    ROW_NUMBER() OVER (
        PARTITION BY p.generacion_id
        ORDER BY p.stat_total DESC
    )                                           AS posicion_en_gen
FROM POKEMON p
JOIN GENERACION g
    ON p.generacion_id = g.generacion_id
ORDER BY g.numero ASC, posicion_en_gen ASC;

-- Interpretación esperada del resultado:
--   Si el promedio_generacion aumenta consistentemente de Gen I a Gen IX,
--   el power creep está confirmado. Una desviación_vs_promedio muy alta
--   en un Pokémon indica que es un outlier de su generación — candidato
--   a nerf (reducción de stats) en futuras actualizaciones del juego.
--   Decisión: Niantic debería establecer un techo de stat_total por
--   generación para mantener la equidad entre jugadores de distintas eras.
