# Drpulse — Diminishing Returns para WoW: Forever

Drpulse es un tracker original de diminishing returns diseñado para la API moderna de **World of Warcraft: Forever (1.60.1 / Interface 16001)**.

**1.0.8: saludo al iniciar sesión; sin validación dentro del cliente.** La compatibilidad de las firmas de API no certifica las reglas de combate ni la disponibilidad de datos en PvP.

## Funciones

- Objetivo, foco y nameplates enemigos.
- Ocho categorías nativas: stun, incapacitate, disorient/fear, root, silence, disarm, taunt y knockback.
- Feed nativo de Blizzard cuando está disponible.
- Fallback por auras visibles con indicador de confianza.
- Temporizador, swipe, estado siguiente (50%, 25%, IMM) e icono del último CC.
- Barras movibles, tamaño configurable, categorías individuales e historial de sesión.
- Vista previa integrada y acceso desde el AddOn Compartment.
- Botón movible del minimapa: clic izquierdo para opciones, derecho para bloquear/desbloquear barras. Su posición se guarda al arrastrarlo.
- Sin dependencias, telemetría ni código de Diminish.

## Precisión del seguimiento

- Los estados se comparten por GUID legible. Si el GUID está restringido, se sigue al objetivo, foco o placa visible sólo mientras conserve ese token; el estado se borra al cambiar de unidad.
- El fallback muestra `CC` mientras queda alguna aura de la categoría. La ventana de reinicio comienza al desaparecer la última.
- Al perder la última unidad observable se descarta el CC activo, sin inventar cuándo terminó. Las cuentas de reinicio ya iniciadas se conservan por GUID.
- El feed nativo tiene prioridad sobre las auras. Su temporizador e inmunidad no se sobrescriben con estimaciones.
- El feed no informa el número de aplicaciones: se muestra `?` cuando no se conoce el porcentaje, e `IMM` cuando confirma inmunidad.
- Si el hechizo de un aura es legible pero su ID de instancia no, se sigue como estimación por hechizo. Si la lectura falla o el hechizo es secreto, se ocultan las estimaciones. Al recuperar la visibilidad se descarta el conteo anterior.
- Sólo se siguen unidades atacables con identidad legible. Cambiar de zona reinicia el seguimiento; se vuelven a leer las unidades visibles.
- Desactivar el feed en Drpulse no desactiva la interfaz nativa de Blizzard. Activarlo solicita la CVar global sólo si el sistema nativo está disponible.
- La base local de hechizos y la ventana estimada de 18 segundos no están certificadas para el ruleset de Forever. Puede faltar cobertura de rangos y variantes. Reaplicaciones que conserven el mismo ID de aura tampoco se pueden contar con fiabilidad desde una instantánea.

## Instalación

1. Localiza la instalación del cliente Forever desde Battle.net y extrae `Drpulse` dentro de su carpeta `Interface/AddOns/` (no anides dos carpetas `Drpulse`).
2. Reinicia el cliente.
3. Escribe `/drpulse` para configurar.

## Comandos

- `/drpulse`: opciones.
- `/drpulse unlock` / `/drpulse lock`: mover o bloquear las barras.
- `/drpulse preview`: vista previa.
- `/drpulse history`: historial de la sesión.
- `/drpulse donate`: muestra el enlace de apoyo en PayPal.
- `/drpulse minimap`: muestra u oculta el botón del minimapa; también disponible en opciones.
- `/drpulse status`: informa si llegan eventos nativos, cuántos datos se pueden leer y qué unidades están disponibles.
- `/drpulse add <spellID> <categoría>`: añadir o corregir un hechizo.
- `/drpulse remove <spellID>`: quitar un hechizo personalizado.
- `/drpulse reset`: restaurar valores.

## Restricciones de Forever

Forever aplica las restricciones modernas de datos de combate. En ciertos contextos PvP los datos de enemigos son secretos para addons. Drpulse no intenta eludir estas restricciones: usa el feed autorizado de Blizzard, procesa auras sólo cuando son legibles y marca los cálculos estimados en gris.

## Apoyar el proyecto

Drpulse es gratuito y seguirá siéndolo. Si te resulta útil en PvP, puedes apoyar futuras actualizaciones con una donación opcional en [PayPal](https://www.paypal.com/paypalme/sebiten). Dentro del juego también puedes usar `/drpulse donate`.

## Publicación en CurseForge

- Juego: World of Warcraft.
- Flavor: Forever.
- Versión: 1.60.1.
- Tipo de release: Beta, pendiente de validación en el cliente.
- Empaqueta la carpeta `Drpulse` como raíz del ZIP.

## Licencia

MIT. Consulta [LICENSE](LICENSE).

## Verificación sin el juego

Desde la raíz del repositorio, con Node.js/npm:

```powershell
npx --yes --package fengari-node-cli fengari tests/Core.spec.lua
npx --yes --package fengari-node-cli fengari tests/UI.spec.lua
```

Las pruebas cubren lógica y ciclo de vida/interfaz. La simulación no reproduce la ejecución segura de WoW ni verifica el aspecto visual real. Consulta `AUDIT.md` en el repositorio para conocer los límites y las fuentes.

