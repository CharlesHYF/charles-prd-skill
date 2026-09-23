/**
 * 原型交互脚本，提供四态切换、角色切换、弹窗与占位提示
 * 创建日期：2026-09-22
 * 修改日期：2026-09-22
 */

const TOAST_DURATION_MS = 2000;

const STATE_LABELS = {
	success: "Success 正常",
	empty: "Empty 空",
	loading: "Loading 加载中",
	error: "Error 失败",
};

const currentState = () => document.body.dataset.state || "success";

const applyState = (stateName) => {
	document.body.dataset.state = stateName;

	document.querySelectorAll("[data-state-btn]").forEach((button) => {
		button.classList.toggle("is-active", button.dataset.stateBtn === stateName);
	});

	document.querySelectorAll("[data-show-state]").forEach((block) => {
		block.hidden = block.dataset.showState !== stateName;
	});
};

const applyRole = (roleName) => {
	document.body.dataset.role = roleName;

	document.querySelectorAll("[data-role-only]").forEach((element) => {
		element.hidden = !element.dataset.roleOnly.split(",").includes(roleName);
	});
};

const showToast = (text) => {
	const toast = document.getElementById("toast");

	if (!toast) {
		return;
	}

	toast.textContent = text;
	toast.hidden = false;
	setTimeout(() => {
		toast.hidden = true;
	}, TOAST_DURATION_MS);
};

const openModal = (modalId) => {
	const modal = document.getElementById(modalId);

	if (modal) {
		modal.hidden = false;
	}
};

const closeModal = (modalId) => {
	const modal = document.getElementById(modalId);

	if (modal) {
		modal.hidden = true;
	}
};

document.querySelectorAll("[data-state-btn]").forEach((button) => {
	button.addEventListener("click", () => applyState(button.dataset.stateBtn));
});

const roleSelect = document.getElementById("roleSelect");

if (roleSelect) {
	roleSelect.addEventListener("change", () => applyRole(roleSelect.value));
}

// 未实现的页面统一给出明确提示，不做成点了没反应的死按钮
document.querySelectorAll("[data-todo]").forEach((element) => {
	element.addEventListener("click", (event) => {
		event.preventDefault();
		showToast(`该页面在 ${element.dataset.todo} 中定义，原型尚未实现`);
	});
});

document.querySelectorAll("[data-open-modal]").forEach((element) => {
	element.addEventListener("click", () => openModal(element.dataset.openModal));
});

document.querySelectorAll("[data-close-modal]").forEach((element) => {
	element.addEventListener("click", () => closeModal(element.dataset.closeModal));
});

applyState(currentState());

if (roleSelect) {
	applyRole(roleSelect.value);
}

window.prototypeHelpers = { showToast, openModal, closeModal, STATE_LABELS };
