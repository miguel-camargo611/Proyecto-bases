-- ============================================================
-- Archivo  : database/sql/ddl/06_stored_procedure.sql
-- Motor    : SQLite 3
-- Propósito: Equivalente de STORED PROCEDURE en SQLite.
--
-- En Cloud Spanner (motor de producción propuesto) esto sería:
--   CREATE PROCEDURE sp_ValidarBatalla(
--       IN p_atacante_id INT64,
--       IN p_defensor_id INT64,
--       IN p_dano       INT64
--   )
--   BEGIN
--     IF p_atacante_id = p_defensor_id THEN
--       SIGNAL 'RN-011: El atacante y el defensor deben ser distintos';
--     END IF;
--   END;
--
-- SQLite no soporta CREATE PROCEDURE.
-- Alternativa equivalente: TRIGGER con lógica multi-paso que se
-- ejecuta automáticamente antes de cada INSERT en REGISTRO_BATALLA.
-- ============================================================

-- Stored Procedure lógico: sp_ValidarBatalla
-- Se ejecuta BEFORE INSERT en REGISTRO_BATALLA.
-- Valida las reglas de negocio de consistencia de batalla
-- que no pueden expresarse como simples CHECK constraints.

CREATE TRIGGER IF NOT EXISTS trg_batalla_validar_participantes
BEFORE INSERT ON REGISTRO_BATALLA
BEGIN

    -- RN-011: Un jugador no puede batallar contra sí mismo
    -- En producción: genera un error 400 en la API con mensaje al cliente
    SELECT CASE
        WHEN NEW.jugador_atacante_id = NEW.jugador_defensor_id
        THEN RAISE(ABORT, 'RN-011: El atacante y el defensor deben ser jugadores distintos')
    END;

    -- RN-012: El daño no puede ser negativo
    -- (Refuerza el CHECK constraint de la tabla con mensaje descriptivo)
    SELECT CASE
        WHEN NEW.dano_infligido < 0
        THEN RAISE(ABORT, 'RN-012: El dano_infligido no puede ser negativo')
    END;

END;

-- ============================================================
-- VERIFICACIÓN DEL TRIGGER
-- ============================================================

-- Prueba 1: debe FALLAR — atacante = defensor (RN-011)
-- INSERT INTO REGISTRO_BATALLA
--     (jugador_atacante_id, jugador_defensor_id,
--      pokemon_atacante_id, pokemon_defensor_id,
--      fecha, dano_infligido, es_victoria_atacante)
-- VALUES (1, 1, 6, 25, '2024-01-01 10:00:00', 100, 1);
-- → Error: RN-011: El atacante y el defensor deben ser jugadores distintos

-- Prueba 2: debe FALLAR — daño negativo (RN-012)
-- INSERT INTO REGISTRO_BATALLA
--     (jugador_atacante_id, jugador_defensor_id,
--      pokemon_atacante_id, pokemon_defensor_id,
--      fecha, dano_infligido, es_victoria_atacante)
-- VALUES (1, 2, 6, 25, '2024-01-01 10:00:00', -50, 1);
-- → Error: RN-012: El dano_infligido no puede ser negativo

-- Prueba 3: debe PASAR — batalla válida
-- INSERT INTO REGISTRO_BATALLA
--     (jugador_atacante_id, jugador_defensor_id,
--      pokemon_atacante_id, pokemon_defensor_id,
--      fecha, dano_infligido, es_victoria_atacante)
-- VALUES (1, 2, 6, 25, '2024-01-01 10:00:00', 250, 1);
-- → 1 row inserted
