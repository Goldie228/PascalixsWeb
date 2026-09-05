document.addEventListener('turbo:load', () => {
	const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
	if (timezone) {
		document.cookie = `time_zone=${timezone}; path=/; max-age=86400`;
	}
});

document.addEventListener('DOMContentLoaded', () => {
	const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
	if (timezone) {
		document.cookie = `time_zone=${timezone}; path=/; max-age=86400`;
	}
});