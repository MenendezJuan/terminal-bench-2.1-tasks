# Terminal-Bench 2.1 — task authoring

Repositorio de autoría de tasks para Terminal-Bench 2.1 (harness Terminus-2, upstream público en [harbor-framework/terminal-bench](https://github.com/harbor-framework/terminal-bench)). Distinto de `quick-hits-aa-briefcase`: ahí se evalúa knowledge-work (Excel/PPTX); acá se evalúan agentes de código sobre bugs reales minados de PRs mergeados, con reward binario por tests.

## Documentación fuente

- [`guidelines/Terminal Bench 2.1 - Guidelines.docx`](guidelines/Terminal%20Bench%202.1%20-%20Guidelines.docx) — metodología completa (el original).
- [`guidelines/guidelines-extracted-text.md`](guidelines/guidelines-extracted-text.md) — mismo contenido en texto plano, para leer rápido o grep.
- [`guidelines/Terminal bench 2.1 - Internal tracking.xlsx`](guidelines/Terminal%20bench%202.1%20-%20Internal%20tracking.xlsx) — tracker de candidatos (repo/PR) y de tasks entregadas (pass@1/3/5, status, categoría).
- [`templates/delivery-template/`](templates/delivery-template/) — la forma exacta que debe tener cada entrega (`harbor-task/` + `evidence/`), placeholders sin contenido real. Ver `LAYOUT.md` ahí adentro.

## El objetivo (resumen de una línea)

Cada task debe hacer fallar a un agente fuerte 5 de 5 veces (`pass@5 ≤ 1`) — con un core difícil detrás de una superficie fácil, no por ambigüedad. Ver `CLAUDE.md` para las reglas operativas al escribir/revisar una task con un agente.

## Estado

Scaffold inicial. Todavía no hay ninguna task minada/escrita — `tasks/` está vacío a propósito. El próximo paso real es Step 1 de la guía: minar un repo candidato (PR mergeado, issue con ≥800 caracteres de repro, fix de 2-6 archivos, tests en el mismo PR, post-cutoff, sin dependency churn).

Pendiente de conseguir: `terminal-bench/tools/package-delivery.sh` (el script que corre los 24 gates) — la guía lo referencia pero no está en el árbol público de `harbor-framework/terminal-bench`; probablemente es tooling interno del cliente. Hasta tenerlo, los gates de `LAYOUT.md` se verifican a mano (el hook de commit ya cubre dos: canary string y "cero em dashes" en `instruction.md`).
