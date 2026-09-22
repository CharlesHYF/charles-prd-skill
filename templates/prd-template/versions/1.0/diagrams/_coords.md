# _coords.json 元素坐标

**来源**：`tools/capture.mjs` 在截图同一时刻用 `getBoundingClientRect()` 量取，与同名 PNG 严格对应。
**获取日期**：2026-09-22
**用途**：生成 `tasks.md` 界面标注的框选位置，避免手写坐标与原型脱节。

结构：`{ "<截图名>": { w, h, els: [{ kind, txt, x, y, w, h }] } }`，
`kind` 取值为 btn / link / menu / field / th / kpi / box。

标注清单按 `txt` 挑元素，同名多个时用 `index` 指定第几个，不写坐标。
