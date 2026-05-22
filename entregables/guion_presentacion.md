# Guion de Presentación: Optimización SGBD Pokémon GO (7 minutos)

> **Consejo para los oradores (Nicolás, Miguel, Camilo):** El objetivo de este guion es hablar con seguridad y pausas estratégicas. Tienen 8 diapositivas y 7 minutos. Hablen pausado, dejen que los números grandes resuenen en la audiencia. Cada diapositiva tiene asignado aproximadamente 45-50 segundos.

---

### Slide 0 — Portada (0:00 - 0:45)
**[Se muestra a Mewtwo y el título "Pokémon GO no debería haber caído"]**

**Orador 1:**
"Buenos días a todos. 
El 6 de julio de 2016, el mundo del gaming cambió para siempre con el lanzamiento de Pokémon GO. Pero ese mismo día, ocurrió uno de los mayores desastres técnicos de la década: el juego estuvo caído por casi 10 horas. 
Hoy, nuestro equipo de ingeniería de datos —Nicolás, Miguel y Camilo— viene a demostrarles que esta caída no fue un problema de mala suerte o de simples servidores. Fue un error de arquitectura de bases de datos que era evitable y que costó cientos de millones. 
Hoy les mostraremos por qué falló y exactamente cómo solucionarlo."

---

### Slide 1 — Contexto 6 Julio 2016 (0:45 - 1:30)
**[Aparece Pikachu y la gráfica de tráfico 50x]**

**Orador 1:**
"Para entender el tamaño del problema, miremos los números reales de ese día. 
Niantic había estimado un tráfico inicial moderado, pero en solo 72 horas, la demanda real multiplicó por 50 esa estimación, alcanzando 45 millones de jugadores concurrentes. 
Ante este tsunami de usuarios, el sistema centralizado de Niantic colapsó. 
Pero el error más grave de todos fue a nivel de base de datos: operaban con cero índices en sus consultas críticas. Veamos por qué esto es matemáticamente insostenible."

---

### Slide 2 — El Problema / Causa Raíz (1:30 - 2:30)
**[Aparece Gengar y la comparativa SCAN vs SEARCH O(n)]**

**Orador 2:**
"El impacto fue catastrófico: más de 200 millones de dólares perdidos en el primer mes y una retención destruida.
La causa raíz de este colapso fue la falta de optimización. Sin índices, cada vez que un jugador atrapaba un Pokémon o visitaba una Poképarada, la base de datos tenía que ejecutar un *'SCAN TABLE'*. Es decir, revisar 450 millones de filas una por una. Esto es una operación de complejidad O(n). 
Si multiplican 450 millones de comparaciones por 45 millones de usuarios haciéndolo al mismo tiempo, el colapso del CPU era inminente. 
Con un índice B-Tree, transformaríamos ese escaneo infinito en una simple búsqueda logarítmica O(log n)."

---

### Slide 3 — La Solución / Arquitectura Dual (2:30 - 3:30)
**[Aparecen Groudon, Kyogre y el diagrama SQL/NoSQL]**

**Orador 2:**
"Nuestra propuesta para Niantic es dividir para conquistar mediante una Arquitectura Dual. 
Por un lado, usamos **Cloud Spanner de Google**, un motor SQL potente y estructurado. Aquí guardamos la base inmutable del juego: catálogos de Pokémon, los tipos, y el progreso de los jugadores. Garantiza total integridad y consistencia.
Por el otro lado, lo dinámico y caótico —como los registros de batallas en tiempo real, las sesiones GPS y las visitas a Poképaradas— lo mandamos a **MongoDB Atlas**. Un motor NoSQL, perfecto para ingerir millones de escrituras por segundo de forma asíncrona.
Todo esto escalado dinámicamente con Kubernetes."

---

### Slide 4 — El Índice B-Tree que lo cambia todo (3:30 - 4:15)
**[Comparativa de código y barras de HP]**

**Orador 3:**
"Aquí pueden ver la ejecución de esta arquitectura en acción. 
Sin índices, como en 2016, el servidor demora unos 300 milisegundos por petición buscando datos a ciegas. 
Con nuestra propuesta, añadimos un simple índice B-Tree a la tabla de Poképaradas. Esta única línea de código SQL reduce la búsqueda de 450 millones de operaciones a **solo 29 comparaciones**. 
En términos prácticos, hicimos que el sistema sea 15 millones de veces más rápido. Pasamos de un sistema colapsado a uno que responde en menos de 1 milisegundo."

---

### Slide 5 — Cuánto Cuesta / ROI (4:15 - 5:15)
**[Aparece Slaking, el reloj en vivo y la factura]**

**Orador 3:**
"Como directivos, su pregunta debe ser: ¿Cuánto cuesta esta infraestructura enterprise? 
Hemos costeado los clústeres en GCP, MongoDB y el equipo humano. La factura mensual de esta solución es de $9,721 dólares. 
Para ponerlo en perspectiva: Pokémon GO genera alrededor de 50 millones de dólares al mes. Nuestro costo operativo representa el 0.019% de sus ingresos mensuales. 
Esta inversión se paga a sí misma en menos de medio día de juego, dándonos un Retorno de Inversión superior al 477,000%. Con menos de 10 mil dólares, blindamos el producto completo."

---

### Slide 6 — Marco Legal Integrado (5:15 - 6:00)
**[Aparecen los escudos de COPPA, Ley 1581, GDPR]**

**Orador 1:**
"Además, no dejamos la ética y legalidad en un papel, la programamos directamente en el núcleo del sistema. 
- Para la ley COPPA en EE.UU., pusimos restricciones tipo 'CHECK' para evitar el registro ilegal de menores. 
- Para el Habeas Data en Colombia y el GDPR en Europa, programamos borrados en cascada ('ON DELETE CASCADE'). Si un jugador decide irse, toda su huella se elimina automática y permanentemente. 
- Operamos bajo normas ISO 27001 asegurando cada credencial con Secret Manager. 
La privacidad y el cumplimiento corren en el propio motor."

---

### Slide 7 — Cierre y Llamado a la Acción (6:00 - 7:00)
**[Aparece Eternatus y el resumen de métricas]**

**Orador 1 o 3:**
"Para concluir. Hoy les entregamos una solución robusta compuesta por 13 tablas SQL, 5 colecciones NoSQL, 11 índices precisos y 6 algoritmos de analítica en tiempo real. 
El costo anual ronda los 125 mil dólares, pero su objetivo es proteger un negocio de 600 millones de dólares anuales. 
Nuestro Roadmap es ágil: 3 meses para la implementación, 6 meses para estar nativos en la nube, y de ahí a escalar al infinito. 
Niantic, la pregunta que dejamos sobre la mesa hoy no es si tienen el presupuesto para pagar esta infraestructura de 9,000 dólares mensuales. La pregunta es si pueden permitirse el lujo de no pagarla, y arriesgarse a caer de nuevo. 
Muchas gracias."
