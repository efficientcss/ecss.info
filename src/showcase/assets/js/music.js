const stream = document.querySelector("#artist-stream");
let loadMore = document.querySelector("#artist-load-more");
let freezeVisibleAlbums = false;
let sectionDetailSweepScheduled = false;
const sectionAlbumContentCache = new Map();
let loadMoreObserver = null;
let loadMoreInFlight = false;
let loadMoreRequestedSectionIndex = 0;
let lastScrollY = window.scrollY;

const assignSectionAlbumIndices = (root = document) => {
	root.querySelectorAll('[data-type="artist-section"]').forEach((section) => {
		const albums = section.querySelectorAll('article[data-type="album"]');
		section.style.setProperty("--album-count", String(albums.length));

		albums.forEach((album, index) => {
			album.style.setProperty("--album-index", String(index + 1));
		});
	});
};

const getSectionBox = (section) => {
	const range = document.createRange();
	range.selectNodeContents(section);
	const box = range.getBoundingClientRect();
	range.detach?.();
	return box;
};

const cacheSectionAlbumContent = (section) => {
	if (!section?.id || sectionAlbumContentCache.has(section.id)) return;

	const albums = Array.from(section.querySelectorAll('article[data-type="album"]'));
	sectionAlbumContentCache.set(section.id, albums.map((album) => album.innerHTML));
};

const unloadSectionAlbumContent = (section) => {
	if (!section || section.dataset.albumContentState === "trimmed") return;
	if (section.querySelector(":target")) return;

	cacheSectionAlbumContent(section);

	section.querySelectorAll('article[data-type="album"]').forEach((album) => {
		album.innerHTML = "";
	});

	section.dataset.albumContentState = "trimmed";
};

const restoreSectionAlbumContent = (section) => {
	if (!section || section.dataset.albumContentState !== "trimmed") return;

	const cachedAlbumBodies = sectionAlbumContentCache.get(section.id);
	if (!cachedAlbumBodies) return;

	section.querySelectorAll('article[data-type="album"]').forEach((album, index) => {
		album.innerHTML = cachedAlbumBodies[index] || album.innerHTML;
	});

	delete section.dataset.albumContentState;
	assignSectionAlbumIndices(section);
	syncVisibleAlbums(section);
	refreshVisibleAlbums();
};

const sweepSectionAlbumContent = () => {
	sectionDetailSweepScheduled = false;
	if (!stream) return;

	const viewportHeight = window.innerHeight;

	stream.querySelectorAll('[data-type="artist-section"]').forEach((section) => {
		const box = getSectionBox(section);
		const isNearViewport = box.bottom > -viewportHeight && box.top < viewportHeight * 2;

		if (isNearViewport) {
			restoreSectionAlbumContent(section);
			return;
		}

		unloadSectionAlbumContent(section);
	});
};

const scheduleSectionAlbumContentSweep = () => {
	if (sectionDetailSweepScheduled) return;
	sectionDetailSweepScheduled = true;
	window.requestAnimationFrame(sweepSectionAlbumContent);
};

const refreshVisibleAlbums = () => {
	document.querySelectorAll('article[data-type="album"] > div > header[data-visibility-observed]').forEach((header) => {
		const album = header.closest('article[data-type="album"]');
		if (!album) return;
		const bounds = header.getBoundingClientRect();
		const isVisible = bounds.bottom > 0 && bounds.top < window.innerHeight;
		album.classList.toggle("is-visible", isVisible);
	});
};

const syncVisibleAlbums = (root = document) => {
	if (!window.IntersectionObserver) return;
	if (!syncVisibleAlbums.observer) {
		syncVisibleAlbums.observer = new IntersectionObserver((entries) => {
			if (freezeVisibleAlbums) return;

			for (const entry of entries) {
				const album = entry.target.closest('article[data-type="album"]');
				if (!album) continue;
				album.classList.toggle("is-visible", entry.isIntersecting);
			}
		}, {
			threshold: 0.1,
		});
	}

	root.querySelectorAll('article[data-type="album"] > div > header:not([data-visibility-observed])').forEach((header) => {
		header.setAttribute("data-visibility-observed", "true");
		syncVisibleAlbums.observer.observe(header);
	});
};

const goToHash = (hash) => {
	if (!hash || hash === location.hash) return;

	if (!document.startViewTransition) {
		location.hash = hash;
		return;
	}

	freezeVisibleAlbums = true;

	document.startViewTransition(() => {
		location.hash = hash;
	}).finished.finally(() => {
		freezeVisibleAlbums = false;
		refreshVisibleAlbums();
	});
};

const buildSectionSelector = (index) => `#artist-section-${index}`;

const ensureLoadMoreObserver = () => {
	if (!stream || !loadMore) return;
	if (loadMoreObserver) return;

	loadMoreObserver = new IntersectionObserver((entries) => {
		for (const entry of entries) {
			if (!entry.isIntersecting) continue;
			triggerLoadMore();
		}
	}, {
		rootMargin: "400px 0px",
	});
};

const rearmLoadMore = () => {
	if (!stream || !loadMore || !window.htmx || stream.dataset.infiniteLoading !== "1") return;

	const totalSections = Number.parseInt(stream.dataset.totalSections || "0", 10);
	const nextSectionIndex = Number.parseInt(stream.dataset.nextSectionIndex || "0", 10);

	if (!totalSections || !nextSectionIndex || nextSectionIndex > totalSections) {
		loadMore.hidden = true;
		loadMore.removeAttribute("data-next-section-index");
		loadMoreObserver?.unobserve(loadMore);
		return;
	}

	loadMore.hidden = false;
	loadMore.setAttribute("data-next-section-index", String(nextSectionIndex));
	ensureLoadMoreObserver();
	loadMoreObserver.unobserve(loadMore);
	loadMoreObserver.observe(loadMore);

	if (loadMore.getBoundingClientRect().top < window.innerHeight + 400) {
		window.requestAnimationFrame(triggerLoadMore);
	}
};

const triggerLoadMore = () => {
	if (!stream || !loadMore || !window.htmx || loadMoreInFlight) return;
	if (loadMore.hidden) return;

	const nextSectionIndex = Number.parseInt(loadMore.getAttribute("data-next-section-index") || "0", 10);
	if (!nextSectionIndex) return;

	loadMoreInFlight = true;
	loadMoreRequestedSectionIndex = nextSectionIndex;

	htmx.ajax("GET", stream.dataset.artistsSource || "artists.html", {
		target: "#artist-stream",
		swap: "beforeend",
		select: buildSectionSelector(nextSectionIndex),
	}).catch(() => {
		loadMoreInFlight = false;
		loadMoreRequestedSectionIndex = 0;
	});
};

document.addEventListener("click", (event) => {
	const nav = event.target.closest("nav");
	if (nav) {
		const link = nav.querySelector('a[href^="#"]');
		if (!link) return;
		event.preventDefault();
		goToHash(link.getAttribute("href"));
		return;
	}

	const link = event.target.closest('a[href^="#"]');
	if (!link) return;

	event.preventDefault();
	goToHash(link.getAttribute("href"));
});

assignSectionAlbumIndices();
syncVisibleAlbums();
refreshVisibleAlbums();
scheduleSectionAlbumContentSweep();

if (stream?.dataset.infiniteLoading === "1" && window.htmx && loadMore) {
	document.body.addEventListener("htmx:afterSwap", (event) => {
		if (!loadMoreInFlight || event.detail.target !== stream) return;

		if (loadMoreRequestedSectionIndex) {
			stream.dataset.nextSectionIndex = String(loadMoreRequestedSectionIndex + 1);
		}

		loadMoreInFlight = false;
		loadMoreRequestedSectionIndex = 0;
		assignSectionAlbumIndices(stream);
		syncVisibleAlbums(stream);
		rearmLoadMore();
		scheduleSectionAlbumContentSweep();
	});

	document.body.addEventListener("htmx:responseError", () => {
		loadMoreInFlight = false;
		loadMoreRequestedSectionIndex = 0;
	});

	document.body.addEventListener("htmx:sendError", () => {
		loadMoreInFlight = false;
		loadMoreRequestedSectionIndex = 0;
	});

	rearmLoadMore();
}

window.addEventListener("scroll", () => {
	const currentScrollY = window.scrollY;
	document.documentElement.classList.toggle("is-scrolling-up", currentScrollY < lastScrollY);
	lastScrollY = currentScrollY;
	scheduleSectionAlbumContentSweep();
}, { passive: true });
