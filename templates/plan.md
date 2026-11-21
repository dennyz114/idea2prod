# <Título de la feature>

**Ticket:** <owner/repo#número, o "pendiente">
**Tamaño:** small | medium | large
**Ejecución:** direct | orchestrate   <!-- direct: la hace un solo agente; orchestrate: una fase por helper -->
**Base:** <rama o commit sobre el que se escribió este plan>

## Contexto

Qué problema resuelve y por qué ahora, en 2 o 3 líneas. Qué código y qué ADRs toca.

## Decisiones

- <decisión> — descartado: <alternativa y por qué>

## Fases

### A1. <nombre>  (mechanical | judgment | critical | ui)
- **Hace:** <qué cambia>
- **Estados** (solo ui): carga, vacío, error, éxito
- **done-check:** `<comando que debe pasar>` → <resultado esperado>

### B1. <nombre>  (...)
- ...

## Riesgos de seguridad y performance

- **Seguridad:** <permisos, input de usuario, datos sensibles, dependencias nuevas; o "ninguno">
- **Performance:** <consultas, listas grandes, bundle; o "ninguno">
- **Datos de prueba:** <qué seed necesita, o "base">

## Fuera de alcance

- <lo que se decidió no hacer, y cuándo valdría la pena>

## Preguntas abiertas

- <ninguna, o lo que falta decidir>
