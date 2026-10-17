# Auditoría 2.0.0-beta.1 — 15 de octubre de 2026

La base activa se reemplaza por los nueve módulos del ZIP Forever DR 0.8.0, adaptados bajo MIT. Los TOC cargan Runtime y el minimapa; no cargan Bootstrap/Core/UI/Options/Data de 1.x.

Las transformaciones de importación afectan nombres de producto, comandos, globals, nombres de módulos, acentos visuales y puntos de integración. El motor y los adaptadores de evidencia mantienen los algoritmos del referente. Integration.lua añade migración no destructiva y el puente al minimapa.

Verificación: 12 escenarios funcionales ejecutados en ambas implementaciones (24 ejecuciones), más migración, recarga, esquema incompatible, análisis de todos los módulos TOC y arranque con constructores visuales sustituidos. Sin errores en Fengari.

Pendiente: validación de opciones/previsualizaciones/renderizado y restricciones reales de WoW. Las estimaciones de lanzamientos están habilitadas igual que en el referente: no equivalen a impactos confirmados. No se promete exactitud cuando el cliente no entrega evidencia pública.

El diseño usa acentos cian y fondos azul oscuro; mantiene los colores semánticos del DR. La barra de foco y el historial de 1.x no están en el runtime del referente. Los datos antiguos se conservan y el ZIP previo permite volver a 1.x.
