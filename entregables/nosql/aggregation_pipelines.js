// ============================================================
// Archivo  : database/nosql/queries/aggregation_pipelines.js
// Motor    : MongoDB Atlas — pokemon_go_nosql
// Propósito: Pipelines de agregación para análisis de negocio.
//            Rúbrica: "2+ consultas/agregaciones" — Fase 4, NoSQL 15 pts
// Ejecutar en mongosh, MongoDB Compass o extensión VS Code MongoDB.
// ============================================================

use("pokemon_go_nosql");

// ── AGG-01: Top 10 Pokémon más usados en batallas + tasa de victoria ─────────
//
// Objetivo de negocio:
//   ¿Qué Pokémon dominan el meta de PvP en Pokémon GO?
//   Niantic usa este análisis para detectar Pokémon sobrepotenciados
//   y aplicar ajustes de balance. Un Pokémon con >70% de tasa de
//   victoria es candidato a nerf en la próxima actualización.
//
// Integración SQL: los pokemon_id y jugador_id en este resultado
//   pueden cruzarse con POKEMON y JUGADOR en SQLite para obtener
//   más contexto (stats base, equipo del jugador, etc.)

db.battle_logs.aggregate([
    {
        $group: {
            _id: "$pokemon_atacante.nombre",
            total_batallas: { $sum: 1 },
            victorias: {
                $sum: { $cond: [{ $eq: ["$resultado", "victoria_atacante"] }, 1, 0] }
            },
            cp_promedio: { $avg: "$pokemon_atacante.cp" }
        }
    },
    {
        $addFields: {
            tasa_victoria_pct: {
                $multiply: [{ $divide: ["$victorias", "$total_batallas"] }, 100]
            }
        }
    },
    { $sort: { total_batallas: -1 } },
    { $limit: 10 },
    {
        $project: {
            _id: 0,
            pokemon: "$_id",
            total_batallas: 1,
            victorias: 1,
            tasa_victoria_pct: { $round: ["$tasa_victoria_pct", 1] },
            cp_promedio: { $round: ["$cp_promedio", 0] }
        }
    }
]);

// Interpretación esperada:
//   Los Pokémon legendarios (Mewtwo, Lugia, Rayquaza) deberían liderar
//   en CP promedio. Un Pokémon "normal" con >60% tasa de victoria indica
//   un desbalance que Niantic debe corregir.


// ── AGG-02: Actividad de sesiones por país — métricas de engagement ──────────
//
// Objetivo de negocio:
//   ¿Dónde están los jugadores más activos?
//   Informa decisiones de eventos presenciales (Community Days, Safari Zones).
//   Un país con alta capturas_promedio y km_promedio indica jugadores
//   comprometidos — mejor candidato para eventos premium con pago.

db.player_sessions.aggregate([
    {
        $group: {
            _id: "$pais",
            total_sesiones: { $sum: 1 },
            jugadores_distintos: { $addToSet: "$jugador_id" },
            duracion_promedio_min: { $avg: "$duracion_minutos" },
            capturas_promedio: { $avg: "$capturas_en_sesion" },
            km_promedio: { $avg: "$km_caminados" }
        }
    },
    {
        $addFields: {
            jugadores_activos: { $size: "$jugadores_distintos" },
            sesiones_por_jugador: {
                $divide: ["$total_sesiones", { $size: "$jugadores_distintos" }]
            }
        }
    },
    { $sort: { total_sesiones: -1 } },
    {
        $project: {
            _id: 0,
            pais: "$_id",
            total_sesiones: 1,
            jugadores_activos: 1,
            sesiones_por_jugador: { $round: ["$sesiones_por_jugador", 1] },
            duracion_promedio_min: { $round: ["$duracion_promedio_min", 1] },
            capturas_promedio: { $round: ["$capturas_promedio", 1] },
            km_promedio: { $round: ["$km_promedio", 2] }
        }
    }
]);

// Interpretación esperada:
//   Colombia (CO) lidera en sesiones totales dado que es el país
//   con más jugadores en los datos sintéticos. España (ES) tiene
//   mayor duración promedio por sesión — jugadores más comprometidos.
//   Decisión: organizar el próximo Community Day en Bogotá (mayor volumen)
//   y el siguiente Safari Zone en Madrid (mayor engagement por jugador).


// ── AGG-03: Barrios de Bogotá con más contenido fotográfico aprobado ─────────
//
// Objetivo de negocio:
//   ¿Qué zonas de Bogotá tienen mejor cobertura fotográfica en el mapa?
//   Niantic usa este dato para priorizar revisores en barrios con backlog
//   de fotos pendientes y para decidir dónde lanzar el próximo Community Day
//   (los barrios con más fotos aprobadas indican mayor actividad de la comunidad).
//
// Integración SQL: lugar_id + tipo_lugar pueden cruzarse con
//   POKEPARADA.pokeparada_id o GIMNASIO.gimnasio_id en SQLite para
//   obtener coordenadas precisas y densidad geográfica.

db.pokestop_fotos.aggregate([
    { $match: { estado: "aprobada" } },
    {
        $group: {
            _id: "$barrio",
            total_fotos: { $sum: 1 },
            votos_promedio: { $avg: "$votos_aprobacion" },
            lugares_distintos: { $addToSet: "$lugar_id" },
            pokeparadas: {
                $sum: { $cond: [{ $eq: ["$tipo_lugar", "pokeparada"] }, 1, 0] }
            },
            gimnasios: {
                $sum: { $cond: [{ $eq: ["$tipo_lugar", "gimnasio"] }, 1, 0] }
            }
        }
    },
    {
        $addFields: {
            lugares_count: { $size: "$lugares_distintos" },
            fotos_por_lugar: {
                $divide: ["$total_fotos", { $size: "$lugares_distintos" }]
            }
        }
    },
    { $sort: { total_fotos: -1 } },
    { $limit: 8 },
    {
        $project: {
            _id: 0,
            barrio: "$_id",
            total_fotos: 1,
            votos_promedio: { $round: ["$votos_promedio", 1] },
            lugares_count: 1,
            fotos_por_lugar: { $round: ["$fotos_por_lugar", 1] },
            pokeparadas: 1,
            gimnasios: 1
        }
    }
]);

// Interpretación esperada:
//   La Candelaria y Salitre lideran (mayor concentración de landmarks
//   históricos y culturales que Niantic asigna como Poképaradas).
//   Un barrio con alto votos_promedio y bajo total_fotos indica
//   comunidad exigente pero con poca aportación — candidato para
//   campaña de incentivos de contribución Wayfarer.


// ── AGG-04: Distribución de IV% por equipo — ¿qué equipo tiene mejores Pokémon? ──
//
// Objetivo de negocio:
//   ¿Los jugadores de Mystic/Valor/Instinct tienen Pokémon con mejores IVs?
//   Niantic puede usar este dato para detectar si un equipo tiene ventaja
//   sistémica (farming en zonas específicas) y balancear los eventos.
//
// Integración SQL: equipo → EQUIPO.nombre, jugador_id → JUGADOR.jugador_id
//   Permite cruzar con nivel promedio del jugador por equipo para ver si
//   el IV alto correlaciona con nivel alto (jugadores más experimentados).

db.pokemon_jugador.aggregate([
    {
        $group: {
            _id: "$equipo",
            total_pokemon: { $sum: 1 },
            iv_pct_promedio: { $avg: "$iv_porcentaje" },
            cp_promedio: { $avg: "$cp_actual" },
            perfectos: {
                $sum: { $cond: [{ $eq: ["$iv_porcentaje", 100] }, 1, 0] }
            },
            lucky_count: { $sum: { $cond: ["$es_lucky", 1, 0] } },
            sombra_count: { $sum: { $cond: ["$es_sombra", 1, 0] } }
        }
    },
    {
        $addFields: {
            pct_lucky: {
                $round: [
                    { $multiply: [{ $divide: ["$lucky_count", "$total_pokemon"] }, 100] },
                    1
                ]
            }
        }
    },
    { $sort: { iv_pct_promedio: -1 } },
    {
        $project: {
            _id: 0,
            equipo: "$_id",
            total_pokemon: 1,
            iv_pct_promedio: { $round: ["$iv_pct_promedio", 1] },
            cp_promedio: { $round: ["$cp_promedio", 0] },
            perfectos: 1,
            lucky_count: 1,
            pct_lucky: 1
        }
    }
]);

// Interpretación esperada:
//   Si Mystic lidera en IV% promedio, sus jugadores farmean más eficientemente
//   (mejor conocimiento del juego, zonas de mayor densidad de spawns).
//   Un equipo con >10% de Pokémon Lucky indica jugadores con muchos amigos
//   de alto nivel — proxy de engagement social alto.


// ── AGG-05 (bonus): Equipos más activos en batallas ──────────────────────────
//
// Objetivo de negocio:
//   ¿Qué equipo (Mystic/Valor/Instinct) gana más batallas?
//   Permite a Niantic balancear eventos para evitar dominancia de un equipo.

db.battle_logs.aggregate([
    {
        $group: {
            _id: "$equipo_atacante",
            total_batallas: { $sum: 1 },
            victorias: {
                $sum: { $cond: [{ $eq: ["$resultado", "victoria_atacante"] }, 1, 0] }
            }
        }
    },
    {
        $addFields: {
            tasa_victoria_pct: {
                $round: [
                    { $multiply: [{ $divide: ["$victorias", "$total_batallas"] }, 100] },
                    1
                ]
            }
        }
    },
    { $sort: { tasa_victoria_pct: -1 } }
]);

// Interpretación esperada:
//   Si Mystic domina con >60% tasa de victoria, Niantic puede ajustar
//   los bonos de equipos en la siguiente actualización para re-balancear.


// ── AGG-06: Ranking de jugadores por tasa de victoria ────────────────────────
//
// Objetivo de negocio:
//   ¿Quiénes son los mejores jugadores en PvP? Este leaderboard
//   es la pantalla central del modo Batalla en Pokémon GO. Niantic
//   lo usa para asignar rangos (Novato → Leyenda) y decidir
//   invitaciones a torneos oficiales.
//
// Por qué perfil_jugador es mejor que un JOIN en SQL:
//   En REGISTRO_BATALLA (SQLite) obtener el historial de un jugador
//   requiere: SELECT + GROUP BY + subconsulta → O(n) sobre toda la tabla.
//   En perfil_jugador (MongoDB) las estadísticas ya están calculadas
//   en el documento → O(1) de lectura, solo se ordena el índice.
//
// Filtro mínimo: jugadores con al menos 3 batallas (evita el ranking
//   siendo liderado por jugadores con 1 batalla ganada).
//
// Colección: perfil_jugador

db.perfil_jugador.aggregate([
    { $match: { "estadisticas.total_batallas": { $gte: 3 } } },
    { $sort: {
        "estadisticas.tasa_victoria_pct": -1,
        "estadisticas.total_batallas": -1
    }},
    {
        $project: {
            _id: 0,
            jugador: "$nombre_entrenador",
            equipo: 1,
            nivel: 1,
            total_batallas: "$estadisticas.total_batallas",
            victorias: "$estadisticas.victorias",
            derrotas: "$estadisticas.derrotas",
            tasa_victoria_pct: "$estadisticas.tasa_victoria_pct",
            dano_promedio: "$estadisticas.dano_promedio_por_batalla",
            pokemon_favorito: "$estadisticas.pokemon_mas_usado"
        }
    }
]);

// Interpretación esperada:
//   El leaderboard debe mostrar diversidad de equipos en el top 10.
//   Un jugador nivel <20 con >80% tasa de victoria es sospechoso de
//   actividad irregular (ban automático en producción).
//   dano_promedio alto + tasa alta = jugador técnicamente superior
//   (no solo tiene suerte — inflige más daño en cada batalla).
