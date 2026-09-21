/**
 * 原型交互脚本，用 Mock 数据演示四种关键状态的切换
 * 创建日期：2026-09-21
 * 修改日期：2026-09-21
 */

const LOADING_DELAY_MS = 600;

const MOCK_ITEMS = [
	{
		id: 1,
		title: "示例条目一",
	},

	{
		id: 2,
		title: "示例条目二",
	},

	{
		id: 3,
		title: "示例条目三",
	},
];

const statePanel = document.getElementById("statePanel");

const renderEmpty = () => {
	statePanel.innerHTML = '<p class="state-empty">还没有任何内容，先创建一条试试</p>';
};

const renderLoading = () => {
	statePanel.innerHTML = '<p class="state-loading">加载中</p>';
};

const renderSuccess = () => {
	const items = MOCK_ITEMS.map((item) => `<li>${item.title}</li>`).join("");
	statePanel.innerHTML = `<ul class="item-list">${items}</ul>`;
};

const renderError = () => {
	statePanel.innerHTML = '<p class="state-error">加载失败，请稍后重试</p>';
};

const renderers = {
	empty: renderEmpty,
	loading: renderLoading,
	success: renderSuccess,
	error: renderError,
};

const switchState = (stateName) => {
	if (stateName === "success") {
		renderLoading();
		setTimeout(renderSuccess, LOADING_DELAY_MS);
		return;
	}

	renderers[stateName]();
};

document.querySelectorAll("[data-state]").forEach((button) => {
	button.addEventListener("click", () => switchState(button.dataset.state));
});

renderEmpty();
