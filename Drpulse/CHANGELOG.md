# Changelog

## 1.0.10 — October 15, 2026

- Process readable crowd-control auras even when other auras on the same unit are restricted.
- Consume readable UNIT_AURA additions, updates and removals immediately, without waiting for polling.
- Limit unavailable indicators to the affected categories instead of hiding every estimated DR on the unit.
- Preserve aura identities across partial scans; show an unknown percentage after an observation gap instead of restarting the count at 50%.
- Expand /drpulse status with the version, aura events, readable CC data, scan errors and unreadable entries.
- Passed 32 core and 48 lifecycle/UI offline tests; this fix still needs validation in Forever. Fully restricted CC cannot be identified without readable aura data or native DR events.

## 1.0.9 — October 15, 2026

- Recheck visible nameplate auras periodically, including plates that become hostile when a duel starts, without requiring another target selection or aura event.
- Detect repeated crowd control with the same aura instance ID when readable application times change, including shorter Polymorph refreshes.
- Recover readable aura tracking when native DR state is cleared or expires while the aura remains visible.
- Preserve the existing DR position above nameplates.
- Pass 32 core and 39 lifecycle/UI offline tests, covering all eight native DR categories, all seven categories with built-in aura fallback, and independent simultaneous categories. Validation of this fix in the Forever client is pending.

## 1.0.8 — October 15, 2026

- Show a short, colored login message with the version and settings command.

## 1.0.7 — October 15, 2026

- Track visible target, focus, and nameplate DR while GUID or attackability is restricted by the client. Token-scoped state is cleared when the observed unit changes, so it cannot be reused for another enemy.
- Show native DR timers when the immunity flag alone is restricted; show `?` for the unknown percentage.
- Estimate readable CC auras by spell ID when the aura instance ID is unavailable.
- Recognize additional level-60 ranks of Polymorph, Hammer of Justice, Fear, Frost Nova, Entangling Roots, Freezing Trap, and Kidney Shot in the aura fallback.
- Add `/drpulse status` diagnostics for native events, restricted data, visible units, and display settings.
- Avoid refreshing nameplates with no DR state on every timer tick.
- Keep rejecting explicitly friendly or nonexistent units. In-game validation is still pending.

## 1.0.6 — October 14, 2026

- Fixed settings controls rendering over the PayPal window. The dialog now uses a dedicated modal layer with an opaque background and blocks clicks behind it.
- Improved settings spacing, section headings, footer alignment, and support button text fit.
- Added a draggable minimap button: left-click opens settings; right-click locks or unlocks the tracker bars.
- Minimap position and visibility are saved between sessions. Toggle visibility in settings or with `/drpulse minimap`.
- Closing the support dialog releases keyboard focus and removes the background input blocker.
- All 45 offline automated tests pass. In-game visual validation is still pending.

## 1.0.5 — 2026-10-14

- Rediseñada la experiencia de apoyo con un botón destacado pero discreto y una ventana visual de PayPal.
- Texto claro: Drpulse seguirá siendo gratuito y la donación es opcional y de una sola vez.
- Añadidos los comandos `/drpulse donate` y `/drpulse support`.
- Añadido el enlace directo de PayPal en README y CurseForge.
- El enlace queda seleccionado para copiar con `Ctrl+C`; el addon no intenta abrir el navegador.

## 1.0.4 — 2026-10-14

- Traducción al inglés de los textos dentro del juego, incluidas las barras Target y Focus, categorías, opciones e historial.
- Añadido un botón Donate que muestra el enlace de PayPal seleccionado para copiar; WoW no permite abrir directamente el navegador desde addons.
- 39 pruebas automatizadas fuera del juego. La validación dentro del cliente Forever sigue pendiente.

## 1.0.2-beta.2 — 2026-10-14

- Cambio de marca a Drpulse, incluido el comando `/drpulse` y el paquete para la carpeta `Drpulse`.
- Compatibilidad de lectura para migrar `DRiftDB` a `DrpulseDB` cuando la variable anterior está disponible.
- 37 pruebas fuera del juego. Distribución marcada Beta; reglas de combate y comportamiento del cliente pendientes de validar.

## 1.0.2-beta.1 — 2026-10-13

- Recuperación de SavedVariables con tipos, rangos y anclajes inválidos.
- Rechazo de eventos, tablas y números ilegibles o malformados antes de operar con ellos.
- Ocultación de estimaciones durante restricciones de auras y reinicio del conteo al recuperar visibilidad.
- Protección contra borrados nativos atrasados; eventos de arena asociados a GUID ya observados.
- Seguimiento limitado a unidades atacables; limpieza al cambiar de mundo y lectura inicial del objetivo/foco.
- Corrección del primer acceso al historial, cierre del historial y sincronización de restablecer opciones.
- Animación radial sin reinicios en cada tick, números duplicados desactivados e icono alternativo si falta la textura del hechizo.
- Desactivar el feed local conserva la preferencia de la interfaz nativa de Blizzard.
- 36 pruebas fuera del juego. Distribución marcada Beta; reglas de combate y comportamiento del cliente pendientes de validar.

## 1.0.1 — 2026-10-13

- Identidad basada únicamente en GUID legibles para evitar mezclar enemigos.
- Reinicio estimado después de la última aura de cada categoría, sin expirar durante CC activo.
- Prioridad del feed nativo y eliminación de la deduplicación temporal de 0,35 segundos.
- Porcentaje desconocido indicado con `?`; inmunidad y duración nativas respetadas.
- Pruebas de regresión de identidad, ciclo de auras y prioridad de fuentes.

## 1.0.0 — 2026-10-13

- Primera versión para WoW: Forever 1.60.1.
- Target, focus y nameplates.
- Integración con SpellDiminishUI y fallback seguro por auras.
- Configuración, vista previa, historial e indicador de confianza.

