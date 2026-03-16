const stream = document.querySelector("#artist-stream");
let loadMore = document.querySelector("#artist-load-more");
let freezeVisibleAlbums = false;

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

const buildArtistSelector = (index) => `#artist-${index}`;

const rearmLoadMore = () => {
	if (!stream || !loadMore || !window.htmx || stream.dataset.infiniteLoading !== "1") return;

	const totalArtists = Number.parseInt(stream.dataset.totalArtists || "0", 10);
	const nextArtistIndex = Number.parseInt(stream.dataset.nextArtistIndex || "0", 10);

	if (!totalArtists || !nextArtistIndex || nextArtistIndex > totalArtists) {
		loadMore.hidden = true;
		loadMore.removeAttribute("hx-select");
		return;
	}

	loadMore.hidden = false;
	loadMore.setAttribute("hx-select", buildArtistSelector(nextArtistIndex));
	loadMore.setAttribute("data-next-artist-index", String(nextArtistIndex));

	const replacement = loadMore.cloneNode(false);
	loadMore.replaceWith(replacement);
	loadMore = replacement;
	htmx.process(replacement);
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

syncVisibleAlbums();
refreshVisibleAlbums();

if (stream?.dataset.infiniteLoading === "1" && window.htmx && loadMore) {
	document.body.addEventListener("htmx:afterSwap", (event) => {
		const source = event.detail.requestConfig?.elt;
		if (source?.id !== "artist-load-more") return;
		if (event.detail.target !== stream) return;

		const nextArtistIndex = Number.parseInt(source.getAttribute("data-next-artist-index") || "0", 10);
		if (!nextArtistIndex) return;

		stream.dataset.endIndex = String(nextArtistIndex);
		stream.dataset.nextArtistIndex = String(nextArtistIndex + 1);
		syncVisibleAlbums(stream);
		rearmLoadMore();
	});

	rearmLoadMore();
}
