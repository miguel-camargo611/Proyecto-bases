-- ============================================================
-- Archivo  : database/sql/ddl/05_fn_calculo.sql
-- Motor    : SQLite 3
-- Propósito: Equivalente de FUNCIÓN en SQLite.
--
-- Función lógica: fn_analizar_captura(captura_id)
-- Calcula métricas de calidad de una captura individual:
--   - Porcentaje de perfección de IVs (0–100%)
--   - Porcentaje del CP máximo alcanzado
--   - Clasificación de calidad (Legendario/Excelente/Bueno/Común)
--
-- SQLite no soporta CREATE FUNCTION con lógica SQL pura.
-- Esta vista es el equivalente directo: cada fila de v_analisis_captura
-- representa el resultado de llamar fn_analizar_captura(captura_id)
-- para esa captura específica.
--
-- Equivalente en Cloud Spanner (producción GCP):
--   CREATE FUNCTION fn_analizar_captura(p_captura_id INT64)
--   RETURNS STRUCT<iv_pct FLOAT64, cp_pct FLOAT64, calidad STRING>
--   AS (
--     SELECT AS STRUCT
--       ROUND(CAST(iv_ataque + iv_defensa + iv_stamina AS FLOAT64) / 45.0 * 100, 1),
--       ROUND(CAST(cp_capturado AS FLOAT64) / NULLIF(max_cp, 0) * 100, 1),
--       CASE
--         WHEN CAST(iv_ataque + iv_defensa + iv_stamina AS FLOAT64) / 45.0 >= 0.96
--           THEN 'Legendario (96-100%)'
--         WHEN CAST(iv_ataque + iv_defensa + iv_stamina AS FLOAT64) / 45.0 >= 0.80
--           THEN 'Excelente (80-95%)'
--         WHEN CAST(iv_ataque + iv_defensa + iv_stamina AS FLOAT64) / 45.0 >= 0.60
--           THEN 'Bueno (60-79%)'
--         ELSE 'Comun (<60%)'
--       END
--     FROM CAPTURA c JOIN POKEMON_GO_STATS gs ON c.pokemon_id = gs.pokemon_id
--     WHERE c.captura_id = p_captura_id
--   );
-- ============================================================

CREATE VIEW IF NOT EXISTS v_analisis_captura AS
SELECT
    c.captura_id,
    j.nombre_entrenador,
    p.nombre                                                        AS pokemon,
    t_tipos.tipos,
    c.cp_capturado,
    gs.max_cp,
    ROUND(CAST(c.cp_capturado AS REAL) / NULLIF(gs.max_cp, 0) * 100, 1)
                                                                    AS pct_cp_maximo,
    c.iv_ataque,
    c.iv_defensa,
    c.iv_stamina,
    ROUND(CAST(c.iv_ataque + c.iv_defensa + c.iv_stamina AS REAL) / 45.0 * 100, 1)
                                                                    AS iv_perfeccion_pct,
    CASE
        WHEN CAST(c.iv_ataque + c.iv_defensa + c.iv_stamina AS REAL) / 45.0 >= 0.96
            THEN 'Legendario (96-100%)'
        WHEN CAST(c.iv_ataque + c.iv_defensa + c.iv_stamina AS REAL) / 45.0 >= 0.80
            THEN 'Excelente (80-95%)'
        WHEN CAST(c.iv_ataque + c.iv_defensa + c.iv_stamina AS REAL) / 45.0 >= 0.60
            THEN 'Bueno (60-79%)'
        ELSE 'Comun (<60%)'
    END                                                             AS calidad_iv,
    c.fecha_captura
FROM CAPTURA c
JOIN JUGADOR j              ON c.jugador_id  = j.jugador_id
JOIN POKEMON p              ON c.pokemon_id  = p.pokemon_id
LEFT JOIN POKEMON_GO_STATS gs ON c.pokemon_id = gs.pokemon_id
LEFT JOIN (
    SELECT pt.pokemon_id,
           GROUP_CONCAT(t.nombre, ' / ') AS tipos
    FROM   POKEMON_TIPO pt
    JOIN   TIPO t ON pt.tipo_id = t.tipo_id
    GROUP  BY pt.pokemon_id
) t_tipos ON p.pokemon_id = t_tipos.pokemon_id;

-- ============================================================
-- Uso equivalente a llamar la función con distintos parámetros:
--
-- Llamar para una captura específica:
--   SELECT * FROM v_analisis_captura WHERE captura_id = 42;
--
-- Ver solo capturas perfectas (100% IVs):
--   SELECT * FROM v_analisis_captura WHERE iv_perfeccion_pct = 100;
--
-- Ranking de capturas legendarias por jugador:
--   SELECT * FROM v_analisis_captura
--   WHERE calidad_iv LIKE 'Legendario%'
--   ORDER BY iv_perfeccion_pct DESC, cp_capturado DESC;
--
-- Distribución de calidad por categoría:
--   SELECT calidad_iv, COUNT(*) AS total,
--          ROUND(AVG(iv_perfeccion_pct), 1) AS iv_promedio,
--          ROUND(AVG(pct_cp_maximo), 1) AS cp_pct_promedio
--   FROM v_analisis_captura
--   GROUP BY calidad_iv
--   ORDER BY iv_promedio DESC;
-- ============================================================
