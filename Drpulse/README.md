# Drpulse — WoW: Forever

Versión 2.0.0-beta.1. Adaptación de Forever DR 0.8.0 (ZIP de referencia), con licencia MIT y atribución a Tarolg. Integración y tema azul de Drpulse por Joaqoz.

## Funcionamiento

- Motor completo del referente: auras por hechizo, feed nativo público/parcial/opaco, lanzamientos propios, mascotas y grupo, feedback de fallos y estimaciones cuando no existe confirmación observable.
- Objetivo y nameplates, filtros por categorías propias, objetos en bolsas, categorías Auto/Always/Never y hechizos personalizados.
- Duraciones aprendidas, reinicio tras el CC, porcentajes/puntos/contador, previsualizaciones, menú contextual y diagnósticos.
- Indicadores estimados en gris: pueden mostrar un lanzamiento sin confirmación de impacto. Se pueden desactivar en Tracking sources → Show unconfirmed casts.
- Si el feed nativo figura como no soportado, las otras fuentes siguen funcionando como en el referente.
- El panel y las opciones siguen la estructura del referente, con acentos azul/cian. Se conserva el botón de minimapa de Drpulse.

## Instalación y migración

Cerrar completamente WoW. Reemplazar la carpeta Drpulse en Interface/AddOns por la del ZIP y volver a abrir el juego. Para comparar resultados, probar cada addon por separado.

La nueva base usa DrpulseV2DB. DrpulseDB y DRiftDB se conservan intactas. Se migran los ajustes compatibles: tamaño, ventana de reinicio, visibilidad, categorías, hechizos personalizados, posición central y minimapa. Las fuentes nuevas parten de los valores del referente. La barra independiente de foco y el historial antiguo no forman parte de esta base; el foco sigue siendo una fuente de seguimiento.

## Comandos

- /drpulse o /rdr: opciones.
- /drpulse status: fuentes, contadores, datos nativos y opciones de Blizzard.
- /drpulse unlock y /drpulse lock: mover/bloquear.
- /drpulse preview: muestra temporal.
- /drpulse clear: borra el seguimiento actual.
- /drpulse all y /drpulse mine: filtro global.
- /drpulse reset: restablece la posición del objetivo.
- Minimapa: clic izquierdo para opciones; derecho para bloquear; arrastrar para mover.

## Validación

12 escenarios se ejecutan contra el código del ZIP original y contra la adaptación: feed no soportado, repeticiones, resistencias, auras observables, mascotas/grupo, área sin confirmar, eventos opacos, identidad secreta, nombres completos, caducidad, duplicados y tiempos restringidos.

También se comprueban migración, conservación de datos, ejecución de los módulos de ambos TOC y conexión de inicio/comandos. La prueba de inicio sustituye los constructores visuales: no valida píxeles, taint ni el cliente real. Esta beta necesita pruebas in game.

Las pruebas Core.spec.lua y UI.spec.lua corresponden a la implementación 1.x, que permanece en el repositorio como historial y no se carga ni se distribuye en esta beta.

## Licencia

MIT. THIRD-PARTY-LICENSE.txt conserva el aviso completo de Tarolg. Los módulos adaptados incluyen atribución. La importación reproducible está en scripts/import-reference.mts; las integraciones propias están en Runtime/Integration.lua.

