// ============================================================
// Archivo  : database/nosql/indexes/mongodb_indexes.js
// Motor    : MongoDB Atlas (M0 Free Tier)
// Base     : pokemon_go_nosql
// Propósito: Índices de las 3 colecciones NoSQL.
//            Ejecutar en mongosh o MongoDB Compass Shell.
// ============================================================

use("pokemon_go_nosql");

// ── battle_logs ───────────────────────────────────────────────
// Filtro más frecuente: historial de batallas de un jugador
db.battle_logs.createIndex(
    { jugador_atacante_id: 1, timestamp: -1 },
    { name: "idx_battle_jugador_ts", background: true }
);

// Cronología global de batallas (timeline)
db.battle_logs.createIndex(
    { timestamp: -1 },
    { name: "idx_battle_ts", background: true }
);

// Búsqueda geoespacial: batallas cerca de una ubicación
db.battle_logs.createIndex(
    { ubicacion: "2dsphere" },
    { name: "idx_battle_geo" }
);

// ── pokestop_fotos ────────────────────────────────────────────
// Lookup directo de fotos de una parada o gimnasio específico
db.pokestop_fotos.createIndex(
    { lugar_id: 1, tipo_lugar: 1 },
    { name: "idx_fotos_lugar" }
);

// Cola de moderación: filtrar fotos por estado (pendiente/aprobada/rechazada)
db.pokestop_fotos.createIndex(
    { estado: 1 },
    { name: "idx_fotos_estado" }
);

// Ranking de fotos más votadas (pantalla de detalle de la Poképarada)
db.pokestop_fotos.createIndex(
    { votos_aprobacion: -1 },
    { name: "idx_fotos_votos" }
);

// Fotos de Poképaradas cercanas a la ubicación del jugador
db.pokestop_fotos.createIndex(
    { ubicacion: "2dsphere" },
    { name: "idx_fotos_geo" }
);

// Filtrar por tipo de foto (dia, frontal, panoramica, etc.)
db.pokestop_fotos.createIndex(
    { etiquetas: 1 },
    { name: "idx_fotos_etiquetas" }
);

// ── pokemon_jugador ───────────────────────────────────────────
// Consulta principal de la mochila — todos los Pokémon del jugador por CP
db.pokemon_jugador.createIndex(
    { jugador_id: 1, cp_actual: -1 },
    { name: "idx_pj_jugador_cp" }
);

// Popularidad de especie en toda la comunidad
db.pokemon_jugador.createIndex(
    { pokemon_id: 1 },
    { name: "idx_pj_pokemon" }
);

// Ranking de Pokémon más perfectos (IV 100%)
db.pokemon_jugador.createIndex(
    { iv_porcentaje: -1 },
    { name: "idx_pj_iv" }
);

// Filtro de mochila — ver solo Pokémon Lucky
db.pokemon_jugador.createIndex(
    { es_lucky: 1 },
    { name: "idx_pj_lucky" }
);

// Heatmap de zonas de captura de cada especie
db.pokemon_jugador.createIndex(
    { ubicacion_captura: "2dsphere" },
    { name: "idx_pj_geo" }
);

// ── player_sessions ───────────────────────────────────────────
// Historial de sesiones por jugador (pantalla "mis actividades")
db.player_sessions.createIndex(
    { jugador_id: 1, inicio: -1 },
    { name: "idx_session_jugador_inicio", background: true }
);

// Análisis de actividad por país (decisiones de eventos regionales)
db.player_sessions.createIndex(
    { pais: 1 },
    { name: "idx_session_pais" }
);

// Densidad de jugadores por zona geográfica
db.player_sessions.createIndex(
    { ubicacion_inicio: "2dsphere" },
    { name: "idx_session_geo" }
);

// Sesiones recientes globales (dashboard de monitoreo en tiempo real)
db.player_sessions.createIndex(
    { inicio: -1 },
    { name: "idx_session_inicio" }
);

// ── perfil_jugador ────────────────────────────────────────────
// Lookup directo por jugador_id (la operación más frecuente — upsert por batalla)
db.perfil_jugador.createIndex(
    { jugador_id: 1 },
    { unique: true, name: "idx_perfil_jugador_id" }
);

// Ranking global por tasa de victoria (pantalla de leaderboard)
db.perfil_jugador.createIndex(
    { "estadisticas.tasa_victoria_pct": -1 },
    { name: "idx_perfil_tasa_victoria" }
);

// Ranking por equipo — top jugadores Mystic/Valor/Instinct
db.perfil_jugador.createIndex(
    { equipo: 1, "estadisticas.victorias": -1 },
    { name: "idx_perfil_equipo_victorias" }
);

// Perfiles con batallas recientes (detectar jugadores inactivos)
db.perfil_jugador.createIndex(
    { ultima_actualizacion: -1 },
    { name: "idx_perfil_ultima_actualizacion" }
);

print("Indices creados en las 4 colecciones (battle_logs, pokestop_fotos, pokemon_jugador, player_sessions, perfil_jugador).");
