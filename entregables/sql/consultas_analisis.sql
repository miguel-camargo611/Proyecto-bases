-- ============================================================
-- Archivo  : database/sql/queries/consultas_analisis.sql
-- Motor    : SQLite 3
-- Propósito: Consultas de agregación y análisis de negocio.
--            Rúbrica: "agregaciones, vistas" — Fase 3, SQL 15 pts
-- ============================================================

-- ── Q-05: Generación con mejor stat_total promedio ───────────
--
-- Objetivo de negocio:
--   ¿Qué generación de Pokémon aporta el contenido más poderoso?
--   Informa la estrategia de lanzamiento: si Gen VII tiene el mayor
--   promedio, su evento de lanzamiento en GO generará más hype y
--   mayor retención de jugadores que el lanzamiento de Gen II.

SELECT
    g.nombre                                    AS generacion,
    g.region,
    g.anio_lanzamiento,
    COUNT(p.pokemon_id)                         AS total_pokemon,
    ROUND(AVG(p.stat_total), 1)                 AS promedio_stat,
    MAX(p.stat_total)                           AS stat_maximo,
    MIN(p.stat_total)                           AS stat_minimo,
    SUM(p.es_legendario)                        AS legendarios,
    SUM(p.es_mitico)                            AS miticos
FROM POKEMON p
JOIN GENERACION g
    ON p.generacion_id = g.generacion_id
GROUP BY g.generacion_id
ORDER BY promedio_stat DESC;

-- Interpretación esperada del resultado:
--   Las generaciones recientes (VI-IX) suelen tener mayor promedio
--   de stat_total — el power creep es un fenómeno documentado.
--   Pero también tienen menos Pokémon disponibles en GO actualmente.
--   Decisión: Niantic debería priorizar el lanzamiento de Pokémon
--   de alto stat_total para mantener la motivación de jugadores
--   veteranos que ya tienen todos los Pokémon de gens anteriores.


-- ── Q-06: HAVING — Tipos con más de 20 Pokémon y velocidad promedio ──
--
-- Objetivo de negocio:
--   ¿Qué tipos son los más representados en el juego y cómo se
--   comparan en velocidad? Un tipo con muchos Pokémon pero baja
--   velocidad promedio es predecible y fácil de contrarrestar —
--   Niantic puede ajustar spawns para mantener variedad en el meta.

SELECT
    t.nombre                                    AS tipo,
    COUNT(DISTINCT pt.pokemon_id)               AS total_pokemon,
    ROUND(AVG(p.velocidad_base), 1)             AS velocidad_promedio,
    ROUND(AVG(p.stat_total), 1)                 AS stat_promedio,
    ROUND(AVG(p.ataque_base), 1)                AS ataque_promedio,
    ROUND(AVG(p.hp_base), 1)                    AS hp_promedio,
    SUM(p.es_legendario)                        AS legendarios_en_tipo
FROM TIPO t
JOIN POKEMON_TIPO pt
    ON t.tipo_id = pt.tipo_id
JOIN POKEMON p
    ON pt.pokemon_id = p.pokemon_id
GROUP BY t.tipo_id
HAVING COUNT(DISTINCT pt.pokemon_id) > 20
ORDER BY total_pokemon DESC;

-- Interpretación esperada del resultado:
--   Agua y Normal son los tipos con más Pokémon (>100 cada uno).
--   Los tipos con mayor velocidad promedio (Volador, Eléctrico)
--   favorecen estilos de juego ofensivos. Decisión: si el meta de
--   PvP está dominado por tipos lentos, Niantic puede incentivar
--   el uso de tipos rápidos mediante eventos temáticos.


-- ── Q-07: Capturas por país — actividad regional (datos sintéticos) ──
--
-- Objetivo de negocio:
--   ¿En qué regiones geográficas hay más actividad de captura?
--   Esta métrica informa dónde organizar eventos presenciales
--   (Community Days, Safari Zones) para maximizar el impacto.
--   También revela mercados subatendidos donde aumentar el spawn rate.

SELECT
    j.pais,
    COUNT(c.captura_id)                         AS total_capturas,
    COUNT(DISTINCT c.jugador_id)                AS jugadores_activos,
    ROUND(AVG(c.cp_capturado))                  AS cp_promedio_capturado,
    ROUND(
        CAST(COUNT(c.captura_id) AS REAL)
        / COUNT(DISTINCT c.jugador_id)
    , 1)                                        AS capturas_por_jugador,
    ROUND(AVG(
        CAST(c.iv_ataque + c.iv_defensa + c.iv_stamina AS REAL) / 45.0 * 100
    ), 1)                                       AS perfeccion_iv_promedio_pct
FROM CAPTURA c
JOIN JUGADOR j
    ON c.jugador_id = j.jugador_id
GROUP BY j.pais
ORDER BY total_capturas DESC;

-- Interpretación esperada del resultado:
--   Colombia (CO) y México (MX) lideran en total de capturas dado
--   que son los países más representados en los datos sintéticos.
--   Un alto capturas_por_jugador indica jugadores más activos/comprometidos.
--   Decisión: los mercados con alta actividad por jugador son ideales
--   para eventos premium — tienen mayor probabilidad de monetización.


-- ── Q-08: Brecha de poder — Legendarios vs. Míticos vs. Normales ──
--
-- Objetivo de negocio:
--   ¿Es el juego fair para jugadores que no tienen legendarios?
--   Si la brecha de stat_total entre categorías es demasiado grande,
--   los jugadores sin legendarios se frustran y abandonan (churn).
--   Este análisis es directamente relevante para los 30M jugadores
--   que dejaron el juego tras el pico de julio 2016.

SELECT
    CASE
        WHEN p.es_legendario = 1 THEN 'Legendario'
        WHEN p.es_mitico     = 1 THEN 'Mítico'
        ELSE                          'Normal'
    END                                         AS categoria,
    COUNT(*)                                    AS cantidad,
    ROUND(AVG(p.stat_total), 1)                 AS stat_promedio,
    MAX(p.stat_total)                           AS stat_maximo,
    MIN(p.stat_total)                           AS stat_minimo,
    ROUND(AVG(p.hp_base), 1)                    AS hp_promedio,
    ROUND(AVG(p.ataque_base), 1)                AS ataque_promedio,
    ROUND(AVG(p.velocidad_base), 1)             AS velocidad_promedio
FROM POKEMON p
GROUP BY categoria
ORDER BY stat_promedio DESC;

-- Interpretación esperada del resultado:
--   Los Legendarios tienen un promedio de stat_total ~100 puntos mayor
--   que los Normales — una brecha significativa pero no insalvable.
--   Los Míticos son pocos pero tienen el stat_total más alto individualmente.
--   Decisión: Niantic debería mantener esta brecha controlada (~80-120 pts)
--   para que los jugadores sin legendarios puedan competir con equipos
--   bien construidos de Pokémon normales. Una brecha mayor al 20%
--   es el umbral que históricamente dispara el churn competitivo.
