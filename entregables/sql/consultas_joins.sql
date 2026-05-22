-- ============================================================
-- Archivo  : database/sql/queries/consultas_joins.sql
-- Motor    : SQLite 3
-- Propósito: Consultas con JOINs y subconsultas correlacionadas.
--            Rúbrica: "JOINs, subconsultas" — Fase 3, SQL 15 pts
-- ============================================================

-- ── Q-01: JOIN 4 tablas — Catálogo Pokédex completo ──────────
--
-- Objetivo de negocio:
--   Niantic necesita una vista unificada de cada Pokémon con su
--   generación, tipos y stats de GO para poblar la pantalla
--   principal del Pokédex en la app. Sin este JOIN, se harían
--   4 queries separadas por Pokémon → colapso a escala masiva.

SELECT
    p.numero_nacional                           AS num,
    p.nombre,
    g.nombre                                    AS generacion,
    g.anio_lanzamiento,
    GROUP_CONCAT(t.nombre, ' / ')               AS tipos,
    p.hp_base,
    p.ataque_base,
    p.defensa_base,
    p.stat_total,
    p.es_legendario,
    p.es_mitico,
    gs.max_cp,
    gs.go_ataque,
    gs.go_defensa,
    gs.go_stamina
FROM POKEMON p
JOIN GENERACION g
    ON p.generacion_id = g.generacion_id
LEFT JOIN POKEMON_TIPO pt
    ON p.pokemon_id = pt.pokemon_id
LEFT JOIN TIPO t
    ON pt.tipo_id = t.tipo_id
LEFT JOIN POKEMON_GO_STATS gs
    ON p.pokemon_id = gs.pokemon_id
GROUP BY p.pokemon_id
ORDER BY gs.max_cp DESC;

-- Interpretación esperada del resultado:
--   Los Pokémon con mayor max_cp aparecen primero — Mewtwo,
--   Slaking y Rayquaza lideran. Esto confirma que los legendarios
--   (es_legendario=1) dominan el ranking de poder en GO.
--   Decisión: Niantic debe limitar los eventos con legendarios
--   para mantener el balance competitivo del juego.


-- ── Q-02: Subconsulta correlacionada — Pokémon "top" por generación ──
--
-- Objetivo de negocio:
--   ¿Qué Pokémon están por encima del promedio de su generación?
--   Identifica los Pokémon "sobresalientes" dentro de cada era
--   del juego — informa qué contenido nuevo tiene mayor impacto
--   en el meta cuando Niantic lanza una nueva generación.

SELECT
    p.nombre,
    g.nombre                                    AS generacion,
    p.stat_total,
    ROUND(
        (SELECT AVG(p2.stat_total)
         FROM POKEMON p2
         WHERE p2.generacion_id = p.generacion_id)
    , 1)                                        AS promedio_gen,
    ROUND(
        p.stat_total -
        (SELECT AVG(p2.stat_total)
         FROM POKEMON p2
         WHERE p2.generacion_id = p.generacion_id)
    , 1)                                        AS diferencia_vs_promedio,
    CASE WHEN p.es_legendario = 1 THEN 'Legendario'
         WHEN p.es_mitico = 1     THEN 'Mítico'
         ELSE 'Normal'
    END                                         AS categoria
FROM POKEMON p
JOIN GENERACION g
    ON p.generacion_id = g.generacion_id
WHERE p.stat_total > (
    SELECT AVG(p3.stat_total)
    FROM POKEMON p3
    WHERE p3.generacion_id = p.generacion_id
)
ORDER BY g.numero ASC, diferencia_vs_promedio DESC;

-- Interpretación esperada del resultado:
--   Aproximadamente el 35-40% de Pokémon supera el promedio de su
--   generación. Las generaciones más recientes (VII-IX) muestran
--   un promedio más alto — el "power creep" es real y documentable.
--   Decisión: Niantic debe analizar si las gens nuevas desequilibran
--   el meta e implementar ajustes de balance preventivos.
