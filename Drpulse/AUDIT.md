## Revisión 1.0.11 — 15 de octubre de 2026

Se reprodujeron fuera del juego el doble conteo al cambiar la legibilidad del ID, la ocultación tras un evento válido seguida de un sondeo fallido y el conteo injustificado por cambios de tiempos. Corregidos con pruebas específicas: 39 de lógica y 50 de UI/ciclo de vida. Las simulaciones no certifican el funcionamiento dentro de Forever.

La consulta de auras sigue las restricciones declaradas por el cliente. El predicado opcional C_Secrets.ShouldUnitAuraIndexBeSecret permite omitir entradas restringidas antes de consultar las siguientes. Los errores reales se guardan en DrpulseDB.lastAuraError y se muestran en /drpulse status. No se usan lanzamientos propios como prueba de que el CC impactó ni se intenta acceder a datos secretos.

Un indicador desconocido conserva únicamente evidencia histórica y caduca; no afirma que haya CC activo ni inmunidad. Si no hay datos legibles ni eventos nativos, el addon no puede reconstruir DR fiables. Las afirmaciones y totales de la revisión histórica siguiente corresponden a versiones anteriores.

Fuentes: [API de restricciones](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua), [precondiciones de acceso](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua).

# Revisión de Drpulse — 2026-10-14

Versión revisada: **1.0.6**. Resultado: 45 pruebas automatizadas fuera de WoW superadas y sintaxis de los seis módulos Lua comprobada con Fengari. Se generó el paquete ZIP; no se ejecutaron build, lint ni pruebas en el cliente.

## Correcciones

| Riesgo encontrado | Corrección |
| --- | --- |
| Opciones guardadas con tipos incorrectos rompían la carga o los anclajes | Valores predeterminados por tipo, límites numéricos, validación de puntos y hechizos personalizados |
| Historial inicialmente visible se ocultaba al intentar abrirlo por primera vez | Creación oculta, apertura correcta y botón de cierre |
| Payload nativo malformado o no finito | Validación antes de indexar o calcular |
| Un borrado nativo atrasado podía eliminar información más reciente | Comprobación de antigüedad previa al borrado |
| Instantáneas restringidas conservaban indicadores estimados visibles | Ocultación del fallback durante la restricción; invalidación del conteo al recuperar lectura |
| Eventos de objetivo repetidos volvían a contar la misma aura | La identidad GUID decide cuándo liberar el estado |
| Estado de encuentros previos y falta de lectura tras cargar | Reinicio y lectura de objetivo, foco y placas al entrar al mundo |
| Eventos de arena podían acumular unidades ajenas a las superficies mostradas | Asociación únicamente con GUID observados; no se guardan tokens auxiliares |
| La opción local del feed apagaba la CVar global | Desactivación local sin apagar el tracker de Blizzard |
| Cambios personalizados o reset dejaban estado/opciones desincronizados | Reinicio del seguimiento y actualización de controles |
| El swipe se reiniciaba diez veces por segundo | Sólo se configura al cambiar el inicio o la duración |
| Textura de hechizo ausente y texto de cooldown duplicado | Icono de categoría como alternativa y ocultación del texto propio del widget |
| El acceso inicial a PayPal era funcional pero visualmente básico | Botón azul/dorado, ventana de apoyo, selección del enlace y comando `/drpulse donate` |
| Los controles de opciones aparecían encima del diálogo de PayPal | Capa FULLSCREEN_DIALOG, fondo opaco y bloqueo de clics detrás; cierre libera foco y bloqueo |
| El texto de apoyo quedaba cortado | Botón más ancho, distribución del pie y márgenes ajustados |
| Faltaba acceso desde el minimapa | Botón con clic izquierdo/derecho, arrastre ajustado a escala y posición/visibilidad persistentes |

## Evidencia y reproducción

Desde la raíz del repositorio:

```powershell
npx --yes --package fengari-node-cli fengari tests/Core.spec.lua
npx --yes --package fengari-node-cli fengari tests/UI.spec.lua
```

Resultados: **24 pruebas de lógica + 21 pruebas de ciclo de vida/UI**. Se incluyen identidad y reutilización de tokens, CC superpuestos, prioridad nativa, payloads parciales, datos secretos simulados, errores de API, opciones dañadas, carga completa, historial, donaciones, cooldown, cambios de mundo y nameplates. Las nuevas pruebas verifican la jerarquía modal y su cierre, clics y arrastre del minimapa, conversión de escala, persistencia, ocultación/restablecimiento y ausencia del minimapa. No reemplazan la verificación visual dentro de WoW.

Las pruebas UI usan un mock explícito de los métodos necesarios, no un cliente WoW. No comprueban píxeles, restricciones de frames protegidos ni el motor real de valores secretos. El centinela usado para datos secretos prueba el orden de las comprobaciones, pero no reproduce toda la semántica del cliente.

## Fuentes contrastadas

- [API extraída del cliente Forever, build 70170, Interface 16001](https://github.com/Atraeau/WoW-Addons/blob/main/docs/api/Spells-Auras-Talents/C_SpellDiminish.md): firmas del feed nativo y estructura del payload.
- [Documentación generada de Blizzard, espejo del código de interfaz](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDiminishUIDocumentation.lua): evento con payload secreto y APIs sujetas a disponibilidad del sistema.
- [Enumeraciones de Blizzard](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDiminishConstantsDocumentation.lua): correspondencia 0–7 de las ocho categorías.
- [Implementación de la bandeja nativa de Blizzard](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SpellDiminishUI/Blizzard_SpellDiminishUITemplates.lua): consumo de inmunidad y cooldown, y CVar utilizada por el tracker nativo.

Los enlaces a ramas son mutables. El espejo `live` sirve como contraste de implementación; no demuestra que todos sus detalles sean idénticos al build Forever instalado.

## Límites pendientes

1. **Disponibilidad en PvP.** Sin GUID, reacción o datos legibles, este addon puede no mostrar seguimiento. El feed autorizado también puede contener secretos. Se descartan; no se promete cobertura universal ni se intenta eludir restricciones.
2. **Reglas reales de DR.** Las firmas de la API no certifican la tabla local de hechizos, rangos, categorías compartidas, duración de reinicio ni la progresión 50/25/inmune de cada categoría. Se conserva la base existente como estimación configurable; `IMM` de origen Aura sigue siendo estimado.
3. **Observación incompleta.** Cargar a mitad de combate, perder visibilidad o recibir una reaplicación con el mismo auraInstanceID impide reconstruir todas las aplicaciones. El fallback nunca debe interpretarse como un registro completo del combate.
4. **Semántica y emisión de eventos.** No se pudo verificar en el cliente que lleguen todas las transiciones nativas a cada superficie ni todas las combinaciones de duración cero/showCountdown. Los tests comprueban el contrato asumido por el addon, no prueban que el servidor lo cumpla.
5. **UI real y seguridad.** Posición sobre nameplates, taint, comportamiento en combate, escala y compatibilidad con otros addons necesitan una sesión en el cliente para certificarse.

No hay una base válida para asignar un porcentaje de fiabilidad ni afirmar margen de error cero. Se distribuye como Beta hasta completar esa validación.
