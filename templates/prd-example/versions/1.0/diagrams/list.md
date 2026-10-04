# list 原型截图

**来源**：本版原型 `../prototype/pages/list.html`，由 `tools/capture.mjs` 自动截取。
**获取日期**：2026-10-04
**视口**：desktop，1440 宽，deviceScaleFactor 2，截图前移除原型状态切换条。
**用途**：`tasks.md` 界面小节的标注底图。

截图时同步量取元素坐标写入 `_coords.json`，标注框位置由该文件生成，不手写坐标。
原型改动后重跑 `node tools/capture.mjs list.json` 即可，截图与坐标不会脱节。
