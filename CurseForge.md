# Drpulse — DR clarity for WoW: Forever

Drpulse muestra el estado de diminishing returns de enemigos en una interfaz limpia, legible y diseñada desde cero para Forever.

**Versión 1.0.13: lectura por hechizo, eventos nativos parciales y correlación estimada de CC directo; 95 pruebas offline aprobadas, pendiente de validación dentro de Forever.**

### Lo importante, de un vistazo

- Verde: el próximo CC dura 50%.
- Ámbar: el próximo CC dura 25%.
- Rojo: inmune.
- Punto azul: estado confirmado.
- Punto gris: estimación o porcentaje desconocido (`?`).
- `CC`: efecto activo; el reinicio estimado empieza cuando termina la última aura de la categoría.

El feed nativo tiene prioridad sobre las estimaciones e informa el temporizador y, cuando es legible, la inmunidad; no informa el número de aplicaciones. Cuando el porcentaje no puede determinarse se muestra `?`. Con un GUID restringido, el seguimiento queda limitado a la vida del objetivo, foco o placa visible.

### Superficies

- Barra movible para objetivo.
- Barra movible para foco.
- Iconos compactos sobre nameplates.
- Historial de DR de la sesión.
- Botón del minimapa movible: clic izquierdo para opciones y derecho para bloquear o desbloquear las barras.

### Diseñado para las reglas nuevas

Forever oculta parte de la información de combate a los addons. Drpulse integra `SpellDiminishUI`, usa auras sólo cuando el cliente permite leerlas y señala cuándo un valor es estimado. Si una instantánea queda restringida se oculta la estimación. No intenta saltarse las restricciones del cliente. La cobertura de hechizos y las reglas estimadas de DR todavía requieren contraste en la beta.

Escribe `/drpulse` para abrir las opciones o `/drpulse status` para diagnosticar datos restringidos. Sin librerías, sin telemetría y sin dependencias.

### Support Drpulse

Drpulse is free and always will be. If it helps you in PvP, you can support future updates with an optional one-time donation.

[Support Drpulse on PayPal](https://www.paypal.com/paypalme/sebiten)

You can also type `/drpulse donate` in game to display the link.

