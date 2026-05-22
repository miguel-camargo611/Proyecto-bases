# 📚 Guía de Estudio Completa — Optimización SGBD Niantic / Pokémon GO
### Equipo: Nicolás · Miguel · Camilo

---

> [!IMPORTANT]
> Esta guía cubre **cada etapa técnica** del proyecto en detalle. Léela de principio a fin antes de la exposición. Tiempo estimado de lectura: 25–30 minutos.

---

## 🗺️ Mapa del Proyecto

```
PROBLEMA REAL (julio 2016)
        ↓
RECOPILACIÓN DE DATOS (PokéAPI + Pokémon GO)
        ↓
DISEÑO SQL — 13 tablas, 9 reglas de negocio, 4 triggers, índices B-Tree
        ↓
DISEÑO NoSQL — 5 colecciones MongoDB Atlas
        ↓
CONSULTAS ANALÍTICAS — JOINs, Ventanas, Agregaciones
        ↓
MARCO LEGAL + FINANCIERO
        ↓
ARQUITECTURA GCP — Cloud Spanner + MongoDB Atlas + Kubernetes
```

---

## ETAPA 0 — El Problema Real (El "por qué" de todo)

### ¿Qué pasó el 6 de julio de 2016?

Pokémon GO se lanzó al mercado y en menos de 72 horas se convirtió en el mayor fenómeno de gaming móvil de la historia. El problema fue que **Niantic no anticipó el volumen**:

| Métrica | Estimado por Niantic | Real en 72 hrs |
|---|---|---|
| Jugadores concurrentes | ~5 millones | **45 millones** (×9) |
| Tráfico al servidor | Línea base | **×50 la estimación original** |
| Caída del sistema | 0 horas | **~10 horas** |
| Pérdida económica | — | **+$200 millones en el primer mes** |

### ¿Cuál fue la causa raíz técnica?

**Falta total de índices en las tablas críticas.** Sin índices, cada consulta ejecuta un `SCAN TABLE` completo:

- **Con 450 millones de filas** en las tablas de actividad
- **45 millones de usuarios** haciendo peticiones simultáneamente
- Cada petición = revisar **450 millones de registros** uno a uno
- Complejidad: **O(n)** → colapso matemáticamente inevitable

### La solución matemática

| Sin índice | Con índice B-Tree |
|---|---|
| O(n) — SCAN TABLE | O(log n) — SEARCH TABLE |
| 450,000,000 comparaciones | **29 comparaciones** |
| ~300 ms por petición | **< 1 ms por petición** |
| Colapso a escala masiva | Sistema funcional a cualquier escala |

> **Frase clave para la exposición:** *"Hicimos el sistema 15 millones de veces más rápido con una sola línea de SQL."*

---

## ETAPA 1 — Los Datasets (Fuentes de Datos)

### ¿De dónde vienen los datos?

El proyecto usó datos **reales**, no inventados. Se extrajeron de dos fuentes:

#### Fuente 1: PokéAPI (datos oficiales del juego)
Archivos CSV descargados de la API oficial:

| Archivo | Contenido | Filas aprox. |
|---|---|---|
| `pokeapi_pokemon.csv` | IDs, nombres, altura, peso, XP base | ~1,000 Pokémon |
| `pokeapi_pokemon_stats.csv` | HP, Ataque, Defensa, Vel. por especie | ~6,000 filas |
| `pokeapi_pokemon_types.csv` | Tipo primario/secundario por Pokémon | ~1,800 filas |
| `pokeapi_pokemon_species.csv` | Si es legendario/mítico, tasa de captura | ~1,000 filas |
| `pokeapi_generations.csv` | 9 generaciones con región y año | 9 filas |
| `pokeapi_regions.csv` | Regiones (Kanto, Johto, Hoenn…) | ~10 filas |
| `pokeapi_types.csv` | Los 18 tipos del juego | 18 filas |
| `pokeapi_type_names.csv` | Nombres de tipos en varios idiomas | ~200 filas |

#### Fuente 2: Pokémon GO Data (datos específicos del móvil)
- **`PokemonGOData.csv`**: Stats exclusivos del modo móvil: `max_cp`, `go_ataque`, `go_defensa`, `go_stamina`

> **¿Por qué dos fuentes?** Los stats base de los Pokémon (HP, Atk, Def) vienen del juego principal. Los stats de GO (CP, Stamina) tienen una fórmula diferente exclusiva del móvil. Necesitamos ambas.

---

## ETAPA 2 — Diseño SQL: El Esquema Relacional

**Archivo:** [`01_schema.sql`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/sql/01_schema.sql)  
**Motor:** SQLite 3 (prototipo local) → **Cloud Spanner** (producción en GCP)

### Las 13 Tablas — Explicación Individual

#### 📦 Tablas de Catálogo (datos inmutables del juego)

**1. `GENERACION`**
```sql
generacion_id, numero, nombre, region, anio_lanzamiento
```
- Almacena las 9 generaciones de Pokémon (Kanto 1996 → Paldea 2022)
- Tabla de referencia: solo 9 filas, nunca crece
- Usada en JOINs para clasificar Pokémon por era

**2. `TIPO`**
```sql
tipo_id, nombre UNIQUE
```
- Los 18 tipos del juego: Fuego, Agua, Eléctrico, Dragón…
- `UNIQUE` garantiza que no pueda existir un tipo duplicado

**3. `POKEMON`** ← *Tabla central del catálogo*
```sql
pokemon_id, numero_nacional UNIQUE, nombre,
hp_base, ataque_base, defensa_base,
ataque_especial_base, defensa_especial_base, velocidad_base,
stat_total, es_legendario, es_mitico, tasa_captura
```
- **RN-002** embebida como `CHECK constraint`:
  ```sql
  CONSTRAINT chk_stat_total CHECK (
      stat_total = hp_base + ataque_base + defensa_base +
                   ataque_especial_base + defensa_especial_base + velocidad_base
  )
  ```
  > Si alguien intenta insertar un Pokémon con stat_total incorrecto, la base de datos lo **rechaza automáticamente**. La integridad es matemática, no manual.

**4. `POKEMON_GO_STATS`**
```sql
pokemon_id PK+FK, max_cp, go_ataque, go_defensa, go_stamina
```
- Relación 1:1 con POKEMON
- Almacena los stats exclusivos de Pokémon GO (no existen en los juegos principales)

**5. `POKEMON_TIPO`** ← *Tabla de relación muchos-a-muchos*
```sql
pokemon_id, tipo_id, slot (1 o 2)
PRIMARY KEY (pokemon_id, tipo_id)
```
- **RN-001** implementada con dos constraints:
  ```sql
  CONSTRAINT chk_slot CHECK (slot IN (1,2))  -- Máximo slot 1 o 2
  CONSTRAINT uq_pokemon_slot UNIQUE (pokemon_id, slot)  -- Un tipo por slot
  ```
- Un Pokémon no puede tener 3 tipos ni dos tipos en el mismo slot

**6. `EQUIPO`**
```sql
equipo_id, nombre UNIQUE, color, lema
```
- Solo 3 filas: Mystic (azul), Valor (rojo), Instinct (amarillo)
- Tabla de referencia estática

#### 👤 Tablas de Jugadores (datos dinámicos)

**7. `JUGADOR`**
```sql
jugador_id AUTOINCREMENT, nombre_entrenador UNIQUE,
email UNIQUE, pais DEFAULT 'CO',
nivel CHECK(BETWEEN 1 AND 50), xp_total,
es_menor_de_edad CHECK(IN(0,1)), equipo_id FK
```
- **RN-006 (COPPA)**: `es_menor_de_edad` activa restricciones en capa de aplicación
- `nivel BETWEEN 1 AND 50`: límite oficial del juego implementado en base de datos

**8. `SESION`**
```sql
sesion_id AUTOINCREMENT, jugador_id FK,
inicio, fin, latitud, longitud, ciudad, pais_sesion,
duracion_minutos CHECK(> 0)
```
- Registra cada vez que un jugador abre la app
- Las coordenadas GPS permiten análisis geográfico

**9. `CAPTURA`** ← *Tabla de alto volumen*
```sql
captura_id AUTOINCREMENT, jugador_id FK, pokemon_id FK,
fecha_captura, cp_capturado CHECK(> 0),
iv_ataque/defensa/stamina CHECK(BETWEEN 0 AND 15),
latitud, longitud
```
- **RN-003**: Los IVs van de 0 a 15 (mecánica oficial)
- **RN-005** → Trigger: fecha de captura no puede ser anterior al registro del jugador
- **RN-007** → Trigger: CP no puede superar el MaxCP oficial de la especie

**10. `POKEPARADA`** ← *Fuente del 80% del tráfico*
```sql
pokeparada_id AUTOINCREMENT, nombre, latitud, longitud,
barrio, ciudad DEFAULT 'Bogotá', pais DEFAULT 'CO',
activa CHECK(IN(0,1))
```
- Los datos representan **landmarks reales de Bogotá**
- Es la tabla que más tráfico genera: cada spin = 1 query
- **Sin índice en esta tabla = la causa principal del colapso de 2016**

**11. `GIMNASIO`**
```sql
gimnasio_id AUTOINCREMENT, nombre, latitud, longitud,
barrio, ciudad, pais, equipo_control FK,
prestigio CHECK(>= 0), activo CHECK(IN(0,1))
```
- Ubicaciones de batallas PvP y Raids
- `equipo_control` indica qué equipo lo domina actualmente

**12. `REGISTRO_BATALLA`**
```sql
batalla_id AUTOINCREMENT,
jugador_atacante_id FK, jugador_defensor_id FK,
pokemon_atacante_id FK, pokemon_defensor_id FK,
gimnasio_id FK, fecha,
dano_infligido CHECK(>= 0),
es_victoria_atacante CHECK(IN(0,1))
```
- Registro histórico ACID de todas las batallas
- **RN-009** → Trigger: atacante ≠ defensor (no puedes batallar contra ti mismo)
- **RN-010** → Trigger: daño ≥ 0

**13. `VISITA_POKEPARADA`** ← *La tabla más crítica del sistema*
```sql
visita_id AUTOINCREMENT, jugador_id FK, pokeparada_id FK,
timestamp_visita DEFAULT(DATETIME('now')),
items_obtenidos CHECK(>= 0)
```
- **A 45M usuarios activos**: ~450 millones de eventos/hora en el pico de 2016
- **Sin índice**: SCAN TABLE en 450M filas → CPU al 100% → colapso
- **RN-013** → Trigger: cooldown de 5 minutos por parada por jugador

---

## ETAPA 3 — Las Reglas de Negocio

**Archivo:** [`reglas_negocio.csv`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/reglas_negocio.csv)

Son las restricciones de integridad que garantizan que la base de datos siempre refleje la realidad del juego. Se implementan en tres niveles:

### Nivel 1: CHECK Constraints (verificación automática en cada INSERT/UPDATE)

| ID | Regla | Implementación |
|---|---|---|
| RN-001 | Máximo 2 tipos por Pokémon (slot 1 o 2) | `CHECK (slot IN (1,2))` + `UNIQUE(pokemon_id, slot)` |
| RN-002 | stat_total = suma de los 6 stats base | `CHECK (stat_total = hp + atk + def + sp_atk + sp_def + spe)` |
| RN-003 | IVs entre 0 y 15 | `CHECK (iv_ataque BETWEEN 0 AND 15)` (×3 columnas) |

### Nivel 2: Triggers BEFORE INSERT (lógica compleja pre-inserción)

| ID | Regla | Trigger |
|---|---|---|
| RN-005 | Captura no puede ser anterior al registro del jugador | `trg_captura_fecha_valida` |
| RN-007 | CP capturado ≤ MaxCP oficial del Pokémon | `trg_captura_cp_valido` |
| RN-009 | Atacante ≠ Defensor en batalla | `trg_batalla_validar_participantes` |
| RN-010 | Daño infligido ≥ 0 | `trg_batalla_validar_participantes` |
| RN-011/RN-013 | Cooldown de 5 min en Poképarada | `trg_visita_pokeparada_cooldown` |

### Nivel 3: Restricciones legales en capa de aplicación

| ID | Regla | Ley |
|---|---|---|
| RN-006 | Menores no pueden hacer compras | COPPA (EE.UU.) + Ley 1581 (Colombia) |

### Ejemplo de Trigger explicado paso a paso

```sql
-- RN-013: Un jugador no puede girar la misma Poképarada más de 1 vez cada 5 minutos
CREATE TRIGGER trg_visita_pokeparada_cooldown
BEFORE INSERT ON VISITA_POKEPARADA  -- Se ejecuta ANTES de insertar
BEGIN
    SELECT CASE
        WHEN EXISTS (
            SELECT 1 FROM VISITA_POKEPARADA
            WHERE jugador_id    = NEW.jugador_id        -- mismo jugador
              AND pokeparada_id = NEW.pokeparada_id      -- misma parada
              AND timestamp_visita > DATETIME(NEW.timestamp_visita, '-5 minutes')
              -- ↑ existe visita en los últimos 5 minutos
        )
        THEN RAISE(ABORT, 'RN-013: cooldown activo — espera 5 minutos')
    END;
END;
```
> **Por qué es importante:** Modela el cooldown real del juego. Además **previene ataques de spam** que en 2016 amplificaron el colapso.

---

## ETAPA 4 — Los Índices B-Tree (La Solución Central)

**Archivo:** [`04_indexes.sql`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/sql/04_indexes.sql)

### ¿Qué es un índice B-Tree?

Un índice B-Tree es una **estructura de datos en árbol balanceado** que SQLite/Cloud Spanner construye separado de la tabla. Permite encontrar cualquier registro sin recorrer toda la tabla.

- **Sin índice**: como buscar una palabra en un libro leyendo página por página → O(n)
- **Con índice**: como usar el índice alfabético del libro → O(log n)

### Los 11 Índices del Proyecto

#### Tabla CAPTURA (2 índices)
```sql
-- El más importante: "mostrar mis capturas recientes" — consulta de la app principal
CREATE INDEX idx_captura_jugador_fecha ON CAPTURA(jugador_id, fecha_captura);

-- "¿cuál es el Pokémon más capturado?" — análisis de popularidad
CREATE INDEX idx_captura_pokemon ON CAPTURA(pokemon_id);
```

#### Tabla SESION (2 índices)
```sql
-- Historial de sesiones por entrenador
CREATE INDEX idx_sesion_jugador ON SESION(jugador_id);

-- Análisis de actividad por rango de fechas
CREATE INDEX idx_sesion_inicio ON SESION(inicio);
```

#### Tabla REGISTRO_BATALLA (2 índices)
```sql
-- Cronología de eventos PvP
CREATE INDEX idx_batalla_fecha ON REGISTRO_BATALLA(fecha);

-- "¿cuántas batallas gané?" — índice compuesto evita lookup extra
CREATE INDEX idx_batalla_atacante_victoria
    ON REGISTRO_BATALLA(jugador_atacante_id, es_victoria_atacante);
```

#### Tabla POKEMON (2 índices)
```sql
-- Filtro de generación (usado por la vista v_pokemon_completo)
CREATE INDEX idx_pokemon_generacion ON POKEMON(generacion_id);

-- Ranking de poder: "top Pokémon más fuertes"
CREATE INDEX idx_pokemon_stat_total ON POKEMON(stat_total DESC);
```

#### Tabla POKEMON_GO_STATS (1 índice)
```sql
-- Valida el trigger RN-007 en cada INSERT de CAPTURA — debe ser ultrarrápido
CREATE INDEX idx_go_stats_maxcp ON POKEMON_GO_STATS(max_cp DESC);
```

#### Tabla VISITA_POKEPARADA (2 índices) ← **El argumento central**
```sql
-- "¿cuándo giré esta parada por última vez?" + valida cooldown RN-013
CREATE INDEX idx_visita_pokeparada_jugador_ts
    ON VISITA_POKEPARADA(jugador_id, timestamp_visita DESC);

-- "¿cuál es la parada más visitada en Bogotá?"
CREATE INDEX idx_visita_pokeparada_parada_ts
    ON VISITA_POKEPARADA(pokeparada_id, timestamp_visita DESC);
```

### Demostración con EXPLAIN QUERY PLAN

```sql
-- ANTES del índice (crisis 2016):
-- → SCAN TABLE VISITA_POKEPARADA   ← lee TODAS las filas

-- DESPUÉS del índice (nuestra solución):
EXPLAIN QUERY PLAN
SELECT * FROM VISITA_POKEPARADA
WHERE jugador_id = 1
ORDER BY timestamp_visita DESC LIMIT 10;
-- → SEARCH TABLE VISITA_POKEPARADA USING INDEX idx_visita_pokeparada_jugador_ts
```

---

## ETAPA 5 — Función y Stored Procedure (equivalentes en SQLite)

### 5.1 La "Función" — Vista `v_analisis_captura`

**Archivo:** [`05_fn_calculo.sql`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/sql/05_fn_calculo.sql)

SQLite no tiene `CREATE FUNCTION` con lógica SQL pura. La solución fue implementarla como una **Vista** que calcula las mismas métricas:

#### ¿Qué calcula la función `fn_analizar_captura`?

Dada una captura específica, calcula tres métricas:

**1. Porcentaje de perfección de IVs** (qué tan "perfecto" es el Pokémon)
```sql
ROUND(CAST(iv_ataque + iv_defensa + iv_stamina AS REAL) / 45.0 * 100, 1) AS iv_perfeccion_pct
-- Máximo posible: 15+15+15 = 45 → 100%
-- Ejemplo: 14+12+15 = 41/45 = 91.1%
```

**2. Porcentaje del CP máximo alcanzado**
```sql
ROUND(CAST(cp_capturado AS REAL) / NULLIF(max_cp, 0) * 100, 1) AS pct_cp_maximo
```

**3. Clasificación de calidad**
```sql
CASE
    WHEN iv_pct >= 0.96 THEN 'Legendario (96-100%)'
    WHEN iv_pct >= 0.80 THEN 'Excelente (80-95%)'
    WHEN iv_pct >= 0.60 THEN 'Bueno (60-79%)'
    ELSE                     'Comun (<60%)'
END AS calidad_iv
```

#### Equivalente en Cloud Spanner (producción):
```sql
CREATE FUNCTION fn_analizar_captura(p_captura_id INT64)
RETURNS STRUCT<iv_pct FLOAT64, cp_pct FLOAT64, calidad STRING>
AS ( ... )
```

### 5.2 El "Stored Procedure" — Trigger `trg_batalla_validar_participantes`

**Archivo:** [`06_stored_procedure.sql`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/sql/06_stored_procedure.sql)

SQLite tampoco tiene `CREATE PROCEDURE`. Se implementó como un trigger multi-paso:

```sql
-- sp_ValidarBatalla ejecutado como trigger:
CREATE TRIGGER trg_batalla_validar_participantes
BEFORE INSERT ON REGISTRO_BATALLA
BEGIN
    -- Paso 1: RN-009 — no batallar contra sí mismo
    SELECT CASE
        WHEN NEW.jugador_atacante_id = NEW.jugador_defensor_id
        THEN RAISE(ABORT, 'RN-011: El atacante y el defensor deben ser jugadores distintos')
    END;

    -- Paso 2: RN-012 — daño no negativo
    SELECT CASE
        WHEN NEW.dano_infligido < 0
        THEN RAISE(ABORT, 'RN-012: El dano_infligido no puede ser negativo')
    END;
END;
```

#### Pruebas de verificación incluidas:
| Prueba | Debe... | Razón |
|---|---|---|
| Atacante = Defensor | FALLAR | RN-011 |
| Daño = -50 | FALLAR | RN-012 |
| Datos válidos | PASAR | Batalla legítima |

---

## ETAPA 6 — Las Consultas SQL Avanzadas

### 6.1 Consultas con JOINs y Subconsultas

**Archivo:** [`consultas_joins.sql`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/sql/consultas_joins.sql)

#### Q-01: JOIN de 4 tablas — Pokédex completo
```sql
SELECT p.nombre, g.nombre AS generacion,
       GROUP_CONCAT(t.nombre, ' / ') AS tipos,
       gs.max_cp
FROM POKEMON p
JOIN GENERACION g ON p.generacion_id = g.generacion_id
LEFT JOIN POKEMON_TIPO pt ON p.pokemon_id = pt.pokemon_id
LEFT JOIN TIPO t ON pt.tipo_id = t.tipo_id
LEFT JOIN POKEMON_GO_STATS gs ON p.pokemon_id = gs.pokemon_id
GROUP BY p.pokemon_id ORDER BY gs.max_cp DESC;
```
> **Justificación de negocio:** Sin este JOIN, la app haría 4 queries separadas por Pokémon → colapso a escala. Un JOIN = una sola query optimizada.

> **Resultado esperado:** Mewtwo, Slaking y Rayquaza lideran el ranking de max_cp.

#### Q-02: Subconsulta correlacionada — Pokémon top por generación
```sql
SELECT p.nombre, p.stat_total,
    ROUND((SELECT AVG(p2.stat_total) FROM POKEMON p2
           WHERE p2.generacion_id = p.generacion_id), 1) AS promedio_gen
FROM POKEMON p
WHERE p.stat_total > (
    SELECT AVG(p3.stat_total) FROM POKEMON p3
    WHERE p3.generacion_id = p.generacion_id  -- correlacionada con la fila exterior
)
ORDER BY diferencia_vs_promedio DESC;
```
> **Por qué es correlacionada:** Para cada Pokémon, calcula el promedio *de su propia generación*. La subconsulta se ejecuta una vez por cada fila → detecta outliers por era.

---

### 6.2 Funciones de Ventana (Window Functions)

**Archivo:** [`consultas_ventanas.sql`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/sql/consultas_ventanas.sql)

> **Nota técnica:** SQLite soporta Window Functions desde la versión 3.25 (septiembre 2018).

#### Q-03: `RANK()` — Ranking por tipo con `PARTITION BY`

```sql
SELECT p.nombre, t.nombre AS tipo_primario, gs.max_cp,
    RANK() OVER (
        PARTITION BY t.tipo_id      -- ranking separado por cada tipo
        ORDER BY gs.max_cp DESC     -- de mayor a menor CP
    ) AS rank_en_tipo,
    COUNT(*) OVER (
        PARTITION BY t.tipo_id      -- total de Pokémon en ese tipo
    ) AS total_en_tipo
FROM POKEMON p
JOIN POKEMON_TIPO pt ON p.pokemon_id = pt.pokemon_id AND pt.slot = 1
JOIN TIPO t ON pt.tipo_id = t.tipo_id
JOIN POKEMON_GO_STATS gs ON p.pokemon_id = gs.pokemon_id;
```

> **Por qué `PARTITION BY` y no `GROUP BY`:** Con `GROUP BY` perderías las filas individuales. `PARTITION BY` mantiene cada Pokémon como fila separada y añade el ranking dentro de su grupo — no colapsa los datos.

> **Resultado esperado:** Mewtwo rank=1 en Psíquico, Rayquaza/Dragonite rank=1 en Dragón.

#### Q-04: `AVG()` de ventana — Power creep entre generaciones

```sql
SELECT g.nombre AS generacion, p.nombre, p.stat_total,
    ROUND(AVG(p.stat_total) OVER (
        PARTITION BY p.generacion_id    -- promedio de esa generación
    ), 1) AS promedio_generacion,
    ROUND(p.stat_total - AVG(p.stat_total) OVER (
        PARTITION BY p.generacion_id
    ), 1) AS desviacion_vs_promedio,
    ROW_NUMBER() OVER (
        PARTITION BY p.generacion_id
        ORDER BY p.stat_total DESC
    ) AS posicion_en_gen
FROM POKEMON p JOIN GENERACION g ON p.generacion_id = g.generacion_id;
```

> **Resultado esperado:** Si `promedio_generacion` aumenta de Gen I a Gen IX → el **power creep** es real y documentable con datos.

---

### 6.3 Consultas de Agregación

**Archivo:** [`consultas_analisis.sql`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/sql/consultas_analisis.sql)

#### Q-05: Generación con mejor stat_total promedio
```sql
SELECT g.nombre, COUNT(p.pokemon_id) AS total_pokemon,
       ROUND(AVG(p.stat_total), 1) AS promedio_stat,
       SUM(p.es_legendario) AS legendarios
FROM POKEMON p JOIN GENERACION g ON p.generacion_id = g.generacion_id
GROUP BY g.generacion_id ORDER BY promedio_stat DESC;
```
> **Decisión de negocio:** La generación con mayor promedio es la que Niantic debe lanzar primero en GO para maximizar hype y retención.

#### Q-06: Tipos con >20 Pokémon y velocidad promedio (`HAVING`)
```sql
SELECT t.nombre, COUNT(DISTINCT pt.pokemon_id) AS total_pokemon,
       ROUND(AVG(p.velocidad_base), 1) AS velocidad_promedio
FROM TIPO t JOIN POKEMON_TIPO pt ON t.tipo_id = pt.tipo_id
            JOIN POKEMON p ON pt.pokemon_id = p.pokemon_id
GROUP BY t.tipo_id
HAVING COUNT(DISTINCT pt.pokemon_id) > 20   -- filtra DESPUÉS de agrupar
ORDER BY total_pokemon DESC;
```
> **Diferencia clave:** `WHERE` filtra antes de agrupar, `HAVING` filtra después. Aquí necesitamos contar primero y luego filtrar los tipos con más de 20.

#### Q-07: Capturas por país (actividad regional)
- Muestra qué regiones tienen más jugadores activos → informa dónde hacer Community Days y Safari Zones

#### Q-08: Brecha de poder Legendarios vs. Míticos vs. Normales
- Si la brecha es > 20% del stat_total promedio → el juego se vuelve injusto y los jugadores sin legendarios hacen churn (se van)

---

## ETAPA 7 — Diseño NoSQL: Las 5 Colecciones de MongoDB

**Motor:** MongoDB Atlas (M0 Free Tier en desarrollo → M10+ en producción)  
**Base de datos:** `pokemon_go_nosql`

### ¿Por qué MongoDB para estos datos?

| Criterio | SQL (Cloud Spanner) | NoSQL (MongoDB) |
|---|---|---|
| Estructura de datos | Fija, esquema rígido | Flexible, documentos variables |
| Transacciones ACID | ✅ Sí | ⚠️ Solo desde v4.0 |
| Escalabilidad de escritura | ✅ Buena | ✅ Excelente (sharding nativo) |
| Arrays anidados | ❌ Requiere tablas extra | ✅ Nativo en documentos |
| Geoespacial | ⚠️ Limitado | ✅ 2dsphere nativo |
| Esquemas evolutivos | ❌ Migration requerida | ✅ Campos opcionales |

### Las 5 Colecciones — Detalle Completo

#### 🗂️ Colección 1: `battle_logs`
**Archivo:** [`battle_logs_schema.json`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/nosql/battle_logs_schema.json)

**¿Para qué sirve?** Registro en tiempo real de batallas PvP. Alta frecuencia de escritura.

**Estructura del documento:**
```json
{
  "_id": "ObjectId()",
  "batalla_id": "BAT-20160716-00001",
  "jugador_atacante_id": 1,       // FK → JUGADOR.jugador_id en SQL
  "equipo_atacante": "Mystic",
  "pokemon_atacante": {
    "pokemon_id": 248,             // FK → POKEMON.pokemon_id en SQL
    "nombre": "Tyranitar",
    "cp": 3671,
    "movimiento_cargado": "Triturar"
  },
  "gimnasio": {
    "gimnasio_id": 1,              // FK → GIMNASIO.gimnasio_id en SQL
    "nombre": "Plaza de Bolívar"
  },
  "resultado": "victoria_atacante",
  "dano_total": 1847,
  "timestamp": "ISODate(...)",
  "ubicacion": { "type": "Point", "coordinates": [-74.076, 4.5981] }
}
```
**¿Por qué MongoDB?** En el pico de 2016, llegaban millones de eventos de batalla por minuto. SQL con transacciones ACID no puede ingerir ese volumen. MongoDB escribe de forma asíncrona.

**Índices:**
- `{jugador_atacante_id: 1, timestamp: -1}` → historial por jugador
- `{timestamp: -1}` → cronología global
- `{ubicacion: "2dsphere"}` → búsqueda geoespacial

---

#### 🗂️ Colección 2: `perfil_jugador`
**Archivo:** [`perfil_jugador_schema.json`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/nosql/perfil_jugador_schema.json)

**¿Para qué sirve?** Perfil completo del jugador con historial de batallas **embebido**. Un documento por jugador.

**Patrón de diseño:** Desnormalización intencional. El historial de batallas está dentro del documento del jugador — no hay JOIN.

```json
{
  "jugador_id": 5,                 // FK → JUGADOR.jugador_id en SQL
  "nombre_entrenador": "AshKetchum",
  "equipo": "Mystic",
  "nivel": 30,
  "batallas": [                    // array embebido — crece con cada batalla
    {
      "batalla_id": 1,
      "rol": "atacante",
      "resultado": "victoria",
      "pokemon_usado": { "nombre": "Charizard", "cp": 3000 },
      "dano_infligido": 342,
      "rival_nombre": "MistyAqua",
      "gimnasio": "Plaza de Bolivar",
      "fecha": "2024-03-15"
    }
  ],
  "estadisticas": {                // métricas pre-calculadas → lectura O(1)
    "total_batallas": 15,
    "victorias": 10,
    "tasa_victoria_pct": 66.7,
    "dano_promedio_por_batalla": 321.3,
    "pokemon_mas_usado": "Charizard"
  }
}
```

**¿Por qué embeber las batallas?** En SQL para ver el historial necesitas: `SELECT + GROUP BY + subconsulta` → O(n) sobre toda la tabla. En MongoDB las estadísticas ya están calculadas → lectura O(1).

---

#### 🗂️ Colección 3: `pokemon_jugador`
**Archivo:** [`pokemon_jugador_schema.json`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/nosql/pokemon_jugador_schema.json)

**¿Para qué sirve?** La "mochila" del jugador — todos los Pokémon que posee con su estado actual.

**¿Por qué MongoDB (y no SQL)?**
- Los Pokémon tienen **variantes con campos distintos**: Sombra tiene `es_sombra+purificado`, Lucky tiene `es_lucky+amigo_intercambio`, formas regionales tienen `forma`. En SQL se necesitarían columnas NULL para todos los Pokémon normales.
- El `historial_fortalecimiento` es un log append-only que crece indefinidamente. En SQL sería una tabla separada con JOIN obligatorio.
- Con 100M jugadores y mochilas de 500+ Pokémon cada una → miles de millones de lecturas/hora.

**Tres variantes de documentos:**
```json
// Normal
{ "pokemon_id": 25, "nombre_especie": "Pikachu", "es_lucky": false, "es_sombra": false }

// Pokémon Sombra (tiene campos extra)
{ "pokemon_id": 6, "nombre_especie": "Charizard", "es_sombra": true, "purificado": false }

// Pokémon Lucky (tiene campos extra distintos)
{ "pokemon_id": 149, "nombre_especie": "Dragonite", "es_lucky": true, "amigo_intercambio": "BrockRock" }
```

---

#### 🗂️ Colección 4: `player_sessions`
**Archivo:** [`player_sessions_schema.json`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/nosql/player_sessions_schema.json)

**¿Para qué sirve?** Sesiones de juego con geolocalización GPS y lista de Poképaradas visitadas.

```json
{
  "sesion_id": "SES-20240315-00042",
  "jugador_id": 1,
  "duracion_minutos": 75,
  "capturas_en_sesion": 12,
  "km_caminados": 3.7,
  "pokeparadas_visitadas": [
    { "pokeparada_id": 1, "nombre": "Catedral Primada de Bogotá" },
    { "pokeparada_id": 2, "nombre": "Museo del Oro" }
  ],
  "ubicacion_inicio": { "type": "Point", "coordinates": [-74.0760, 4.5977] },
  "pais": "CO"
}
```

**Uso:** Análisis de densidad de jugadores → decidir dónde hacer Community Days y Safari Zones.

---

#### 🗂️ Colección 5: `pokestop_fotos`
**Archivo:** [`pokestop_fotos_schema.json`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/nosql/pokestop_fotos_schema.json)

**¿Para qué sirve?** Fotos comunitarias de Poképaradas y Gimnasios (sistema Niantic Wayfarer). Moderación con votos.

**¿Por qué MongoDB?** Durante Community Days, miles de jugadores suben fotos simultáneamente. Fotos de pokeparadas tienen campos distintos a fotos de gimnasios (`equipo_control`). SQL con transacciones ACID no escala aquí.

---

## ETAPA 8 — Los Índices MongoDB (Colección NoSQL)

**Archivo:** [`mongodb_indexes.js`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/nosql/mongodb_indexes.js)

### Resumen de índices por colección

| Colección | Índice | Propósito |
|---|---|---|
| `battle_logs` | `{jugador_atacante_id:1, timestamp:-1}` | Historial por jugador |
| `battle_logs` | `{ubicacion: "2dsphere"}` | Batallas cercanas a ti |
| `pokestop_fotos` | `{lugar_id:1, tipo_lugar:1}` | Fotos de una parada específica |
| `pokestop_fotos` | `{estado:1}` | Cola de moderación (pendientes) |
| `pokestop_fotos` | `{votos_aprobacion:-1}` | Fotos más votadas |
| `pokemon_jugador` | `{jugador_id:1, cp_actual:-1}` | Mochila ordenada por CP |
| `pokemon_jugador` | `{iv_porcentaje:-1}` | Ranking de Pokémon perfectos |
| `pokemon_jugador` | `{ubicacion_captura: "2dsphere"}` | Heatmap de capturas |
| `player_sessions` | `{jugador_id:1, inicio:-1}` | Historial de sesiones |
| `player_sessions` | `{ubicacion_inicio: "2dsphere"}` | Densidad por zona |
| `perfil_jugador` | `{jugador_id:1}` UNIQUE | Lookup directo por jugador |
| `perfil_jugador` | `{"estadisticas.tasa_victoria_pct":-1}` | Leaderboard global |
| `perfil_jugador` | `{equipo:1, "estadisticas.victorias":-1}` | Ranking por equipo |

> **Total: 13+ índices MongoDB** — cada uno justificado con un caso de uso de negocio real.

---

## ETAPA 9 — Los Pipelines de Agregación MongoDB

**Archivo:** [`aggregation_pipelines.js`](file:///c:/Users/Miguel%20Camargo/Downloads/entregables/entregables/nosql/aggregation_pipelines.js)

Son el equivalente NoSQL de las consultas SQL de análisis. Se ejecutan en `mongosh` o MongoDB Compass.

### AGG-01: Top 10 Pokémon más usados en batallas + tasa de victoria

```javascript
db.battle_logs.aggregate([
    { $group: {                        // paso 1: agrupar por Pokémon
        _id: "$pokemon_atacante.nombre",
        total_batallas: { $sum: 1 },
        victorias: { $sum: { $cond: [{ $eq: ["$resultado", "victoria_atacante"] }, 1, 0] } },
        cp_promedio: { $avg: "$pokemon_atacante.cp" }
    }},
    { $addFields: {                    // paso 2: calcular tasa de victoria
        tasa_victoria_pct: { $multiply: [{ $divide: ["$victorias", "$total_batallas"] }, 100] }
    }},
    { $sort: { total_batallas: -1 } }, // paso 3: ordenar
    { $limit: 10 },                    // paso 4: top 10
    { $project: { pokemon: "$_id", tasa_victoria_pct: { $round: ["$tasa_victoria_pct", 1] } } }
])
```
> **Decisión de negocio:** Un Pokémon con >70% tasa de victoria es candidato a nerf (reducción de poder) en la próxima actualización.

---

### AGG-02: Actividad de sesiones por país
- Informa qué países tienen jugadores más activos → priorizar eventos presenciales
- Colombia lidera en sesiones; España tiene mayor duración por sesión

### AGG-03: Barrios de Bogotá con más fotos aprobadas
- Identifica zonas con mayor actividad comunitaria
- La Candelaria y Salitre lideran (mayor concentración de landmarks históricos)

### AGG-04: Distribución de IV% por equipo
- ¿Qué equipo (Mystic/Valor/Instinct) tiene mejores Pokémon?
- Si Mystic tiene >55% IV promedio → ventaja sistémica → Niantic ajusta eventos

### AGG-05: Tasa de victorias por equipo en batallas
- Si un equipo domina con >60% → balanceo en la siguiente actualización

### AGG-06: Leaderboard global de jugadores por tasa de victoria
```javascript
db.perfil_jugador.aggregate([
    { $match: { "estadisticas.total_batallas": { $gte: 3 } } }, // mínimo 3 batallas
    { $sort: {
        "estadisticas.tasa_victoria_pct": -1,
        "estadisticas.total_batallas": -1
    }},
    { $project: {
        jugador: "$nombre_entrenador",
        equipo: 1, nivel: 1,
        tasa_victoria_pct: "$estadisticas.tasa_victoria_pct",
        pokemon_favorito: "$estadisticas.pokemon_mas_usado"
    }}
])
```
> **¿Por qué NoSQL es mejor aquí?** En SQL: `SELECT + GROUP BY + subconsulta` → O(n). En MongoDB: las estadísticas ya están en el documento → **O(1) de lectura**.

---

## ETAPA 10 — Arquitectura Dual (La Propuesta de Solución)

### El principio: "Dividir para conquistar"

```
┌─────────────────────────────────────────────────────┐
│              DATOS DEL JUEGO                        │
│                                                     │
│  ESTÁTICO / ESTRUCTURADO      DINÁMICO / CAÓTICO   │
│  ─────────────────────        ─────────────────    │
│  Catálogo Pokémon             Batallas en tiempo   │
│  Stats por especie            real                  │
│  Progreso del jugador         Sesiones GPS          │
│  Reglas de negocio            Fotos comunitarias    │
│  Historial de batallas        Mochila del jugador   │
│  (con ACID)                   (escritura masiva)    │
│         ↓                            ↓              │
│   Cloud Spanner              MongoDB Atlas          │
│   (SQL, ACID, GCP)           (NoSQL, sharding)      │
└─────────────────────────────────────────────────────┘
                    ↕ Integración por IDs ↕
                (jugador_id, pokemon_id, etc.)
```

### Herramienta de orquestación: Kubernetes en GCP
- Escala los contenedores automáticamente según la demanda
- Si el tráfico sube ×10 (otro lanzamiento), Kubernetes añade pods sin intervención manual

### Seguridad: Secret Manager (ISO 27001)
- Credenciales de base de datos almacenadas en GCP Secret Manager
- Nunca en código ni variables de entorno en texto plano

---

## ETAPA 11 — Marco Legal y Ético

### Tres marcos legales implementados directamente en la BD

#### 1. COPPA — Children's Online Privacy Protection Act (EE.UU.)
- **Qué prohíbe:** Recolectar datos de menores de 13 años sin consentimiento parental
- **Cómo se implementó:**
  ```sql
  -- En tabla JUGADOR:
  es_menor_de_edad INTEGER CHECK (es_menor_de_edad IN (0,1))
  -- En capa de aplicación: si es_menor_de_edad=1, bloquear INSERT en COMPRA
  ```
- **En producción (Cloud Spanner):** TRIGGER BEFORE INSERT en tabla COMPRA

#### 2. Ley 1581 de 2012 — Habeas Data (Colombia)
- **Qué exige:** El usuario tiene derecho a borrar todos sus datos del sistema
- **Cómo se implementó:** `ON DELETE CASCADE` en todas las FK de JUGADOR
  - Si se elimina un jugador → se eliminan automáticamente sus capturas, sesiones, visitas y batallas
  - Ningún dato huérfano permanece en la base de datos

#### 3. GDPR — General Data Protection Regulation (Europa)
- **Qué exige:** Mismo derecho al olvido, consentimiento explícito, portabilidad de datos
- **Implementación:** Mismo mecanismo de cascade delete + encriptación de emails en producción

### Integración con ISO 27001
- Secret Manager gestiona credenciales
- Auditoría de accesos a datos sensibles
- Política de retención de datos definida

---

## ETAPA 12 — Análisis Financiero y ROI

### El costo mensual de la solución

| Componente | Costo mensual |
|---|---|
| Cloud Spanner (GCP) — 3 nodos | ~$3,600 |
| MongoDB Atlas M10 — clúster | ~$2,400 |
| Kubernetes Engine (GKE) | ~$1,800 |
| Networking + Load Balancer | ~$921 |
| Equipo técnico (parcial) | ~$1,000 |
| **TOTAL** | **~$9,721 USD/mes** |

### El ROI que justifica todo

| Métrica | Valor |
|---|---|
| Ingresos mensuales de Pokémon GO | ~$50,000,000 USD |
| Costo de la solución | $9,721 USD |
| Costo como % de ingresos | **0.019%** |
| Pérdida por el colapso de 2016 | +$200,000,000 |
| ROI (retorno de inversión) | **>477,000%** |

> **Frase clave:** *"La pregunta no es si tienen el presupuesto para pagar $9,721/mes. La pregunta es si pueden permitirse el lujo de NO pagarlo y arriesgarse a caer de nuevo."*

---

## ETAPA 13 — El Roadmap de Implementación

```
MES 1–3: FASE SQL (Fundación)
├── Deploy Cloud Spanner con las 13 tablas
├── Migración de datos de SQLite a Cloud Spanner
├── Configuración de índices en producción
└── Validación de triggers y reglas de negocio

MES 3–6: FASE NOSQL (Expansión)
├── Deploy MongoDB Atlas M10
├── Migración de datos dinámicos
├── Activación de índices 2dsphere
└── Pruebas de carga a escala de millones de usuarios

MES 6+: FASE CLOUD NATIVE (Escala)
├── Kubernetes con auto-scaling
├── Secret Manager para seguridad
├── Dashboard de monitoreo en tiempo real
└── Escalado a escala global (Kubernetes + CDN)
```

---

## 📊 Resumen de Métricas del Proyecto

| Métrica | Cantidad |
|---|---|
| Tablas SQL | **13 tablas** |
| Reglas de negocio implementadas | **9 reglas (RN-001 a RN-013)** |
| Triggers en la base de datos | **4 triggers** |
| Índices SQL | **11 índices B-Tree** |
| Colecciones MongoDB | **5 colecciones** |
| Índices MongoDB | **13+ índices** |
| Pipelines de agregación | **6 pipelines** |
| Consultas SQL avanzadas | **8 consultas (Q-01 a Q-08)** |
| Costo mensual de la solución | **$9,721 USD** |
| ROI estimado | **>477,000%** |

---

## 🎯 Preguntas Frecuentes que Podrían Hacerte

**P: ¿Por qué SQLite y no directamente Cloud Spanner?**
> R: SQLite es para prototipado local y demostración. La arquitectura final propuesta para producción es Cloud Spanner. Usamos SQLite porque es gratuito, portable y suficiente para demostrar la lógica de negocio.

**P: ¿Cómo se comunican el SQL y el MongoDB?**
> R: Mediante IDs compartidos. El `jugador_id` de la tabla `JUGADOR` en SQL es el mismo que el campo `jugador_id` en MongoDB. La capa de aplicación (API) es responsable de mantener la consistencia entre ambos motores.

**P: ¿Por qué no usar solo MongoDB para todo?**
> R: Los datos de catálogo (Pokémon, reglas del juego, historial de batallas con ACID) requieren integridad referencial fuerte y transacciones ACID. MongoDB no garantiza ACID en operaciones multi-colección de la misma forma que SQL. Usamos cada motor donde es más fuerte.

**P: ¿Qué es una función de ventana y para qué sirve?**
> R: Es una función SQL que calcula un valor para cada fila usando un "grupo" de filas relacionadas, sin colapsar las filas (a diferencia de `GROUP BY`). Ejemplo: `RANK() OVER (PARTITION BY tipo)` da el puesto de cada Pokémon dentro de su tipo, manteniendo todos los Pokémon como filas individuales.

**P: ¿Cómo prueban que los índices funcionan?**
> R: Con `EXPLAIN QUERY PLAN`. Si el plan dice `SCAN TABLE` → no hay índice. Si dice `SEARCH TABLE USING INDEX nombre_indice` → el índice está activo y funciona.

**P: ¿La solución es escalable a nivel global?**
> R: Sí. Cloud Spanner está diseñado para escala global con consistencia fuerte. MongoDB Atlas con sharding puede manejar billones de documentos. Kubernetes escala los pods de la API automáticamente. El sistema puede pasar de 45M a 450M usuarios sin rediseño.

---

## 🗣️ Guía de Exposición por Orador

| Slide | Orador | Tiempo | Tema |
|---|---|---|---|
| 0 — Portada | Orador 1 | 0:00–0:45 | El lanzamiento y el desastre |
| 1 — Contexto 2016 | Orador 1 | 0:45–1:30 | Los números del colapso |
| 2 — El Problema | Orador 2 | 1:30–2:30 | O(n) vs O(log n) |
| 3 — La Solución | Orador 2 | 2:30–3:30 | Arquitectura Dual |
| 4 — El Índice B-Tree | Orador 3 | 3:30–4:15 | 15 millones de veces más rápido |
| 5 — El ROI | Orador 3 | 4:15–5:15 | $9,721 vs $200M de pérdida |
| 6 — Marco Legal | Orador 1 | 5:15–6:00 | COPPA, Ley 1581, GDPR |
| 7 — Cierre | Orador 1/3 | 6:00–7:00 | El reto final |

---

*¡Éxito en la exposición! 🎮*
